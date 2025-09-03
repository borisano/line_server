# frozen_string_literal: true

require 'sinatra'
require 'json'
require_relative 'lib/line_index'

# Salsify Line Server - High-performance file line serving
class SalsifyLineServer < Sinatra::Base
  configure do
    set :port, 4567
    set :bind, '0.0.0.0'
    set :logging, true

    # Initialize the line index on startup (skip in test environment)
    unless ENV['RACK_ENV'] == 'test'
      file_path = ENV['SALSIFY_FILE_PATH']
      if file_path.nil? || file_path.empty?
        puts 'Error: SALSIFY_FILE_PATH environment variable not set'
        exit 1
      end

      puts "Initializing line index for: #{file_path}"
      start_time = Time.now

      begin
        @@line_index = Salsify::LineIndex.new(file_path)
        index_time = Time.now - start_time
        puts "Line index built in #{index_time.round(2)}s"
      rescue StandardError => e
        puts "Error initializing line index: #{e.message}"
        exit 1
      end
    end
  end

  # Initialize line index for testing or manual setup
  def self.initialize_index(file_path)
    @@line_index = Salsify::LineIndex.new(file_path)
  end

  # Health check endpoint
  get '/' do
    content_type :json
    {
      status: 'ok',
      file: ENV['SALSIFY_FILE_PATH'],
      lines: @@line_index.line_count,
      message: 'Salsify Line Server is running'
    }.to_json
  end

  # Main API endpoint: GET /lines/<line_index>
  get '/lines/:line_number' do
    line_number = params[:line_number].to_i

    # Validate line number
    if line_number < 1
      content_type :json
      halt 400, { error: 'Line number must be positive' }.to_json
    end

    # Get the line
    line = @@line_index.get_line(line_number)

    if line.nil?
      # Line doesn't exist (beyond end of file)
      content_type :json
      halt 413, { error: 'Line index beyond end of file' }.to_json
    end

    # Return the line content
    content_type :text
    line
  end

  # Handle invalid routes
  not_found do
    content_type :json
    { error: 'Not found. Use GET /lines/<line_number>' }.to_json
  end

  # Handle errors
  error do |e|
    content_type :json
    { error: 'Internal server error', message: e.message }.to_json
  end
end

# Run the server if this file is executed directly
SalsifyLineServer.run! if __FILE__ == $0
