# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
end

require 'rspec'
require 'rack/test'
require 'tempfile'
require 'fileutils'
require 'stringio'

# Set up test environment
ENV['RACK_ENV'] = 'test'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.warnings = true

  config.default_formatter = 'doc' if config.files_to_run.one?

  config.order = :random
  Kernel.srand config.seed
end

# Helper method to silence output during tests
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
