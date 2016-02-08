$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rspec'
require 'table_rotate'
require 'support/global_helper_methods'
require 'support/test_model'

RSpec.configure do |config|
  config.include ActiveRecord::ConnectionAdapters::SchemaStatements
  config.order = 'random'
end
