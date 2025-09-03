# frozen_string_literal: true

require_relative 'spec_helper'
require_relative '../app'
require 'tempfile'

RSpec.describe SalsifyLineServer do
  include Rack::Test::Methods

  def app
    SalsifyLineServer
  end

  let(:temp_file) { Tempfile.new('server_test') }
  let(:test_content) { "First line\nSecond line\nThird line\nFourth line\n" }

  before do
    temp_file.write(test_content)
    temp_file.close

    # Initialize the line index for testing
    silence_output do
      SalsifyLineServer.initialize_index(temp_file.path)
    end
  end

  after do
    temp_file.unlink
  end

  describe 'GET /' do
    it 'returns server status' do
      get '/'

      expect(last_response).to be_ok
      expect(last_response.content_type).to include('application/json')

      response_data = JSON.parse(last_response.body)
      expect(response_data['status']).to eq('ok')
      expect(response_data['lines']).to eq(4)
      expect(response_data['file']).to be_nil # Not set in test environment
      expect(response_data['message']).to include('Salsify Line Server')
    end
  end

  describe 'GET /lines/:line_number' do
    context 'with valid line numbers' do
      it 'returns the correct line for line 1' do
        get '/lines/1'

        expect(last_response).to be_ok
        expect(last_response.content_type).to include('text/plain')
        expect(last_response.body).to eq('First line')
      end

      it 'returns the correct line for line 2' do
        get '/lines/2'

        expect(last_response).to be_ok
        expect(last_response.body).to eq('Second line')
      end

      it 'returns the correct line for line 4' do
        get '/lines/4'

        expect(last_response).to be_ok
        expect(last_response.body).to eq('Fourth line')
      end
    end

    context 'with invalid line numbers' do
      it 'returns 400 for line number 0' do
        get '/lines/0'

        expect(last_response.status).to eq(400)
        expect(last_response.content_type).to include('application/json')

        response_data = JSON.parse(last_response.body)
        expect(response_data['error']).to eq('Line number must be positive')
      end

      it 'returns 400 for negative line numbers' do
        get '/lines/-1'

        expect(last_response.status).to eq(400)

        response_data = JSON.parse(last_response.body)
        expect(response_data['error']).to eq('Line number must be positive')
      end

      it 'returns 413 for line numbers beyond file end' do
        get '/lines/5'

        expect(last_response.status).to eq(413)
        expect(last_response.content_type).to include('application/json')

        response_data = JSON.parse(last_response.body)
        expect(response_data['error']).to eq('Line index beyond end of file')
      end

      it 'returns 413 for very large line numbers' do
        get '/lines/999999'

        expect(last_response.status).to eq(413)

        response_data = JSON.parse(last_response.body)
        expect(response_data['error']).to eq('Line index beyond end of file')
      end
    end

    context 'with non-numeric line numbers' do
      it 'treats non-numeric as 0 and returns 400' do
        get '/lines/abc'

        expect(last_response.status).to eq(400)

        response_data = JSON.parse(last_response.body)
        expect(response_data['error']).to eq('Line number must be positive')
      end
    end
  end

  describe 'error handling' do
    it 'returns 404 for unknown routes' do
      get '/unknown'

      expect(last_response.status).to eq(404)
      expect(last_response.content_type).to include('application/json')

      response_data = JSON.parse(last_response.body)
      expect(response_data['error']).to eq('Not found. Use GET /lines/<line_number>')
    end
  end

  describe 'performance under load' do
    it 'handles multiple concurrent requests efficiently' do
      threads = []
      results = []
      mutex = Mutex.new

      # Simulate 20 concurrent requests
      20.times do |i|
        threads << Thread.new do
          line_num = (i % 4) + 1 # Cycle through lines 1-4
          response = get "/lines/#{line_num}"

          mutex.synchronize do
            results << {
              status: response.status,
              line_num: line_num,
              body: response.body
            }
          end
        end
      end

      threads.each(&:join)

      expect(results.length).to eq(20)
      results.each do |result|
        expect(result[:status]).to eq(200)
        expect(result[:body]).to match(/line/)
      end
    end
  end

  private

  def silence_output
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    yield
  ensure
    $stdout = original_stdout
    $stderr = original_stderr
  end
end
