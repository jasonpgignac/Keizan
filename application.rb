require "rubygems"
require "bundler/setup"
require 'yaml'
require 'active_record'
require 'zendesk'

require './app/models/event'
require './app/models/comment'
require './app/models/satisfaction_rating'
require './app/models/ticket'
require './app/models/value_change'
require './app/models/tag'
require './app/models/group'
require './app/models/organization'
require './app/models/user'

# Connect to the Database
db_config = YAML::load(File.open(File.join(File.dirname(__FILE__),'config','database.yml')))
ActiveRecord::Base.establish_connection(db_config)

# Connect to Zendesk
zendesk_config = YAML::load(File.open(File.join(File.dirname(__FILE__),'config','zendesk.yml')))
CLIENT = Zendesk.configure do |config|  
  config.url = zendesk_config["url"]

  config.username = zendesk_config["username"]
  config.password = zendesk_config["password"]

  config.retry = true
  config.log = true
end



