require 'simplecov'
require 'simplecov-rcov'
SimpleCov.formatter = SimpleCov::Formatter::RcovFormatter
SimpleCov.start
SimpleCov.minimum_coverage 96.3

require 'vcr'
VCR.configure do |config|
  config.cassette_library_dir = 'fixtures/vcr_cassettes'
  config.hook_into :webmock
end

require 'minitest/autorun'
require 'ghtorrent'
require 'mocha/minitest'
require 'byebug'


