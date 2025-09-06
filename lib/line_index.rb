# frozen_string_literal: true

module Salsify
  # High-performance file line indexer with automatic memory/disk switching
  # Pre-builds an index of byte offsets for O(1) line access
  class LineIndex
    attr_reader :file_path, :line_count

    def initialize(file_path)
      @file_path = File.expand_path(file_path)
      raise ArgumentError, "File does not exist: #{@file_path}" unless File.exist?(@file_path)
      raise ArgumentError, "File is not readable: #{@file_path}" unless File.readable?(@file_path)

      @file_size = File.size(@file_path)
      @line_count = 0

      # Memory threshold from environment variable (default 512MB)
      threshold_mb = ENV.fetch('MEMORY_THRESHOLD_MB', '512').to_i
      @memory_threshold = threshold_mb * 1024 * 1024

      # Force disk index if environment variable is set
      force_disk = ENV.fetch('FORCE_DISK_INDEX', 'false').downcase == 'true'
      @use_disk_index = force_disk
      @index_file = "#{@file_path}.idx"
      @line_offsets = []

      build_or_load_index
    end

    # Get line by 1-based index
    # Returns nil if line doesn't exist
    def get_line(line_number)
      return nil if line_number < 1 || line_number > @line_count

      line_index = line_number - 1
      start_offset = get_line_offset(line_index)
      return nil unless start_offset

      # Calculate end offset (next line start or EOF)
      end_offset = get_line_offset(line_index + 1) || @file_size

      # Remove trailing newline from length calculation
      length = end_offset - start_offset
      length -= 1 if line_index + 1 < @line_count

      return '' if length <= 0

      File.open(@file_path, 'rb') do |file|
        file.seek(start_offset)
        line = file.read(length)
        # Remove trailing newline if present
        line&.chomp || ''
      end
    rescue StandardError => e
      warn "Error reading line #{line_number}: #{e.message}"
      nil
    end

    private

    def build_or_load_index
      # Check if index file exists and is newer than source file
      if File.exist?(@index_file) && File.mtime(@index_file) > File.mtime(@file_path)
        load_existing_index
      else
        build_index
        save_index if @use_disk_index
      end
    end

    def build_index
      puts "Building line index for #{@file_path}..."
      start_time = Time.now

      # Estimate memory requirements unless forced to use disk
      unless @use_disk_index
        estimated_lines = estimate_line_count
        estimated_memory = estimated_lines * 8 # 8 bytes per offset

        # Switch to disk index if estimated memory exceeds threshold
        @use_disk_index = true if estimated_memory > @memory_threshold
      end

      if @use_disk_index
        if ENV.fetch('FORCE_DISK_INDEX', 'false').downcase == 'true'
          puts 'Forced disk-based indexing enabled.'
        elsif @file_size > 10 * 1024 * 1024 * 1024
          # For very large files, skip estimation and just indicate size-based decision
          puts "Large file detected (#{format_bytes(@file_size)}). Using disk-based indexing." # > 10GB
        else
          estimated_lines = estimate_line_count
          estimated_memory = estimated_lines * 8
          puts "Large file detected (#{format_bytes(estimated_memory)} index). Using disk-based indexing."
        end
        build_disk_index
      else
        estimated_lines = estimate_line_count
        estimated_memory = estimated_lines * 8
        puts "Using memory-based indexing (#{format_bytes(estimated_memory)} index)."
        build_memory_index
      end

      elapsed = Time.now - start_time
      puts "Indexed #{@line_count} lines in #{@file_path} (#{format_bytes(@file_size)}) - #{elapsed.round(2)}s"
    end

    def estimate_line_count
      # Sample first 64KB to estimate average line length
      sample_size = [64 * 1024, @file_size].min

      File.open(@file_path, 'rb') do |file|
        sample = file.read(sample_size)
        lines_in_sample = sample.count("\n")
        return 1 if lines_in_sample == 0

        # Calculate average line length including newlines
        avg_line_length = sample_size.to_f / lines_in_sample

        # For very uniform files, be more conservative in estimation
        estimated_lines = (@file_size / avg_line_length).to_i

        # Cap the estimation to prevent ridiculous values
        max_reasonable_lines = @file_size / 2 # Minimum 2 bytes per line
        [estimated_lines, max_reasonable_lines].min
      end
    end

    def build_memory_index
      @line_offsets = []
      @line_count = 0

      return if @file_size.zero? # Handle empty files

      # Add first line offset
      @line_offsets << 0
      @line_count = 1

      File.open(@file_path, 'rb') do |file|
        buffer_size = 64 * 1024 # 64KB chunks
        position = 0

        while (chunk = file.read(buffer_size))
          chunk.each_byte.with_index do |byte, index|
            if byte == 10 # ASCII newline character (\n)
              next_line_start = position + index + 1
              if next_line_start < @file_size
                @line_offsets << next_line_start
                @line_count += 1
              end
            end
          end
          position += chunk.size
        end
      end
    end

    def build_disk_index
      # Write index directly to disk to avoid memory issues
      @line_count = 0

      File.open(@index_file, 'wb') do |index_file|
        # Only write first offset if file is not empty
        unless @file_size.zero?
          # Write first offset (0)
          index_file.write([0].pack('Q<')) # 64-bit little-endian
          @line_count = 1
        end

        File.open(@file_path, 'rb') do |file|
          buffer_size = 1024 * 1024 # 1MB chunks for large files
          position = 0
          lines_processed = 0

          while (chunk = file.read(buffer_size))
            chunk.each_byte.with_index do |byte, index|
              if byte == 10 # newline
                next_line_start = position + index + 1
                if next_line_start < @file_size
                  index_file.write([next_line_start].pack('Q<'))
                  @line_count += 1

                  lines_processed += 1
                  puts "  Processed #{lines_processed / 1_000_000}M lines..." if lines_processed % 1_000_000 == 0
                end
              end
            end
            position += chunk.size
          end
        end
      end
    end

    def load_existing_index
      if File.exist?(@index_file)
        puts 'Loading existing disk index...'
        @use_disk_index = true
        @line_count = File.size(@index_file) / 8 # 8 bytes per offset
      else
        # Fallback to building new index
        build_index
      end
    end

    def save_index
      puts "Index saved to #{@index_file}"
    end

    def get_line_offset(line_index)
      if @use_disk_index
        return nil if line_index >= @line_count

        File.open(@index_file, 'rb') do |file|
          file.seek(line_index * 8)
          data = file.read(8)
          return nil unless data && data.length == 8

          data.unpack1('Q<')
        end
      else
        @line_offsets[line_index]
      end
    end

    def format_bytes(bytes)
      return "#{bytes} bytes" if bytes < 1024

      units = %w[KB MB GB TB]
      size = bytes.to_f
      unit_index = 0

      while size >= 1024 && unit_index < units.length - 1
        size /= 1024.0
        unit_index += 1
      end

      "#{size.round(2)} #{units[unit_index]}"
    end
  end
end
