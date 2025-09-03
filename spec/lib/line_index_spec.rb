# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/line_index'

RSpec.describe Salsify::LineIndex do
  let(:temp_file) { Tempfile.new('test_file') }
  let(:test_content) do
    "Line 1\nLine 2\nLine 3\nLine 4 with more content\n\nLine 6 after empty line\n"
  end

  before do
    temp_file.write(test_content)
    temp_file.close
  end

  after do
    temp_file.unlink
  end

  describe '#initialize' do
    context 'with valid file' do
      it 'creates an index successfully' do
        index = described_class.new(temp_file.path)
        expect(index.file_path).to eq(File.expand_path(temp_file.path))
        expect(index.line_count).to eq(6)
      end
    end

    context 'with non-existent file' do
      it 'raises ArgumentError' do
        expect { described_class.new('/non/existent/file') }
          .to raise_error(ArgumentError, /File does not exist/)
      end
    end

    context 'with empty file' do
      let(:empty_file) { Tempfile.new('empty') }

      before { empty_file.close }
      after { empty_file.unlink }

      it 'handles empty file correctly' do
        index = described_class.new(empty_file.path)
        expect(index.line_count).to eq(0)
      end
    end

    context 'with single line file without newline' do
      let(:single_line_file) { Tempfile.new('single') }

      before do
        single_line_file.write('Single line without newline')
        single_line_file.close
      end

      after { single_line_file.unlink }

      it 'indexes single line correctly' do
        index = described_class.new(single_line_file.path)
        expect(index.line_count).to eq(1)
        expect(index.get_line(1)).to eq('Single line without newline')
      end
    end
  end

  describe '#get_line' do
    let(:index) { described_class.new(temp_file.path) }

    context 'with valid line numbers' do
      it 'returns correct lines' do
        expect(index.get_line(1)).to eq('Line 1')
        expect(index.get_line(2)).to eq('Line 2')
        expect(index.get_line(3)).to eq('Line 3')
        expect(index.get_line(4)).to eq('Line 4 with more content')
        expect(index.get_line(5)).to eq('') # Empty line
        expect(index.get_line(6)).to eq('Line 6 after empty line')
      end
    end

    context 'with invalid line numbers' do
      it 'returns nil for line number 0' do
        expect(index.get_line(0)).to be_nil
      end

      it 'returns nil for negative line numbers' do
        expect(index.get_line(-1)).to be_nil
      end

      it 'returns nil for line numbers beyond file end' do
        expect(index.get_line(7)).to be_nil
        expect(index.get_line(100)).to be_nil
      end
    end
  end

  describe 'performance characteristics' do
    let(:large_content) do
      (1..10_000).map { |i| "This is line #{i} with some content" }.join("\n") + "\n"
    end

    let(:large_file) { Tempfile.new('large_test') }

    before do
      large_file.write(large_content)
      large_file.close
    end

    after { large_file.unlink }

    it 'handles large files efficiently' do
      start_time = Time.now
      index = described_class.new(large_file.path)
      index_time = Time.now - start_time

      expect(index.line_count).to eq(10_000)
      expect(index_time).to be < 1.0 # Should index 10k lines in under 1 second

      # Test random access performance
      access_start = Time.now
      100.times do |i|
        line_num = rand(1..10_000)
        line = index.get_line(line_num)
        expect(line).to include("line #{line_num}")
      end
      access_time = Time.now - access_start

      expect(access_time).to be < 0.1 # 100 random accesses in under 0.1 seconds
    end
  end

  describe 'edge cases' do
    context 'with file containing only newlines' do
      let(:newlines_file) { Tempfile.new('newlines') }

      before do
        newlines_file.write("\n\n\n")
        newlines_file.close
      end

      after { newlines_file.unlink }

      it 'handles newline-only file correctly' do
        index = described_class.new(newlines_file.path)
        expect(index.line_count).to eq(3)
        expect(index.get_line(1)).to eq('')
        expect(index.get_line(2)).to eq('')
        expect(index.get_line(3)).to eq('')
      end
    end

    context 'with file containing special characters' do
      let(:special_file) { Tempfile.new('special') }

      before do
        special_file.write("Line with\ttab\nLine with spaces   \nLine with!@#$%^&*()\n")
        special_file.close
      end

      after { special_file.unlink }

      it 'preserves special characters' do
        index = described_class.new(special_file.path)
        expect(index.get_line(1)).to eq("Line with\ttab")
        expect(index.get_line(2)).to eq('Line with spaces   ')
        expect(index.get_line(3)).to eq("Line with!@\#$%^&*()")
      end
    end
  end
end
