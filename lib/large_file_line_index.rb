# frozen_string_literal: true

require 'mmap'

module Salsify
  # Memory-efficient file line indexer for very large files
  # Uses disk-based index and memory mapping for files larger than RAM
  class LargeFileLineIndex
    attr_reader :file_path, :line_count

    def initialize(file_path)
      @file_path = File.expand_path(file_path)
      raise ArgumentError, "File does not exist: #{@file_path}" unless File.exist?(@file_path)
      raise ArgumentError, "File is not readable: #{@file_path}" unless File.readable?(@file_path)

      @file_size = File.size(@file_path)
      @index_file = "#{@file_path}.idx"
      @line_count = 0

      # Memory threshold: if index would exceed 1GB, use disk-based approach
      @memory_threshold = 1024 * 1024 * 1024 # 1GB
      @use_disk_index = false

      build_or_load_index
    end

    # Get line by 1-based index
    def get_line(line_number)
      return nil if line_number < 1 || line_number > @line_count

      line_index = line_number - 1
      start_offset = get_line_offset(line_index)
      end_offset = get_line_offset(line_index + 1) || @file_size

      # Remove trailing newline from length calculation
      length = end_offset - start_offset
      length -= 1 if line_index + 1 < @line_count

      return '' if length <= 0

      # Use memory mapping for large files
      if @use_disk_index && @file_size > 100 * 1024 * 1024 # 100MB+
        read_line_mmap(start_offset, length)
      else
        read_line_traditional(start_offset, length)
      end
    rescue StandardError => e
      warn "Error reading line #{line_number}: #{e.message}"
      nil
    end

    private

    def build_or_load_index
      # Check if index file exists and is newer than source file
      if File.exist?(@index_file) && File.mtime(@index_file) > File.mtime(@file_path)
        load_index
      else
        build_index
        save_index if @use_disk_index
      end
    end

    def build_index
      puts "Building line index for #{@file_path}..."
      start_time = Time.now

      # Estimate memory requirements
      estimated_lines = estimate_line_count
      estimated_memory = estimated_lines * 8 # 8 bytes per offset

      @use_disk_index = estimated_memory > @memory_threshold

      if @use_disk_index
        puts 'Large file detected. Using disk-based indexing.'
        build_disk_index
      else
        puts 'Using memory-based indexing.'
        build_memory_index
      end

      elapsed = Time.now - start_time
      puts "Index built in #{elapsed.round(2)}s"
    end

    def estimate_line_count
      # Sample first 1MB to estimate average line length
      sample_size = [1024 * 1024, @file_size].min

      File.open(@file_path, 'rb') do |file|
        sample = file.read(sample_size)
        lines_in_sample = sample.count("\n")
        return 1 if lines_in_sample == 0

        avg_line_length = sample_size.to_f / lines_in_sample
        (@file_size / avg_line_length).to_i
      end
    end

    def build_memory_index
      @line_offsets = [0] # First line always starts at 0
      @line_count = 1

      File.open(@file_path, 'rb') do |file|
        buffer_size = 1024 * 1024 # 1MB chunks for large files
        position = 0

        while (chunk = file.read(buffer_size))
          chunk.each_byte.with_index do |byte, index|
            if byte == 10 # newline
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
      @line_count = 1
      lines_processed = 0

      File.open(@index_file, 'wb') do |index_file|
        # Write first offset (0)
        index_file.write([0].pack('Q<')) # 64-bit little-endian

        File.open(@file_path, 'rb') do |file|
          buffer_size = 1024 * 1024 # 1MB chunks
          position = 0

          while (chunk = file.read(buffer_size))
            chunk.each_byte.with_index do |byte, index|
              if byte == 10 # newline
                next_line_start = position + index + 1
                if next_line_start < @file_size
                  index_file.write([next_line_start].pack('Q<'))
                  @line_count += 1

                  lines_processed += 1
                  puts "Processed #{lines_processed / 1_000_000}M lines..." if lines_processed % 1_000_000 == 0
                end
              end
            end
            position += chunk.size
          end
        end
      end
    end

    def load_index
      if File.exist?(@index_file)
        puts 'Loading existing index...'
        @use_disk_index = true
        @line_count = File.size(@index_file) / 8 # 8 bytes per offset
      else
        # Fallback to memory index
        @line_offsets = []
        @use_disk_index = false
      end
    end

    def save_index
      # Index is already saved during build_disk_index
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

    def read_line_mmap(start_offset, length)
      # Use memory mapping for efficient large file access
      Mmap.open(@file_path, 'r') do |mmap|
        mmap[start_offset, length].chomp
      end
    rescue LoadError
      # Fallback if mmap gem not available
      read_line_traditional(start_offset, length)
    end

    def read_line_traditional(start_offset, length)
      File.open(@file_path, 'rb') do |file|
        file.seek(start_offset)
        file.read(length).chomp
      end
    end
  end
end
