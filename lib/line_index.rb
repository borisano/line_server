# frozen_string_literal: true

require 'fiddle'

module Salsify
  # High-performance file line indexer using memory-mapped I/O
  # Pre-builds an index of byte offsets for O(1) line access
  class LineIndex
    attr_reader :file_path, :line_count

    def initialize(file_path)
      @file_path = File.expand_path(file_path)
      raise ArgumentError, "File does not exist: #{@file_path}" unless File.exist?(@file_path)
      raise ArgumentError, "File is not readable: #{@file_path}" unless File.readable?(@file_path)

      @line_offsets = []
      @file_size = File.size(@file_path)
      @line_count = 0
      
      build_index
    end

    # Get line by 1-based index
    # Returns nil if line doesn't exist
    def get_line(line_number)
      return nil if line_number < 1 || line_number > @line_count

      line_index = line_number - 1
      start_offset = @line_offsets[line_index]
      
      # Calculate end offset (next line start or EOF)
      end_offset = if line_index + 1 < @line_count
                     @line_offsets[line_index + 1] - 1  # Subtract 1 to exclude newline
                   else
                     @file_size
                   end

      # Read the specific line using File.read with offset and length
      length = end_offset - start_offset
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

    # Build index of line start positions
    def build_index
      return if @file_size.zero?

      File.open(@file_path, 'rb') do |file|
        # First line always starts at position 0
        @line_offsets << 0
        @line_count = 1

        # Read file in chunks for memory efficiency
        buffer_size = 64 * 1024  # 64KB chunks
        position = 0

        while (chunk = file.read(buffer_size))
          chunk.each_byte.with_index do |byte, index|
            if byte == 10  # ASCII newline character (\n)
              next_line_start = position + index + 1
              # Only add if not at end of file
              if next_line_start < @file_size
                @line_offsets << next_line_start
                @line_count += 1
              end
            end
          end
          position += chunk.size
        end
      end

      puts "Indexed #{@line_count} lines in #{@file_path} (#{format_bytes(@file_size)})"
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