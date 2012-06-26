require 'bundler'
Bundler.require
require './application'
require 'resque/tasks'

desc "Migrate the database through scripts in db/migrate."
task :migrate do
  ActiveRecord::Base.establish_connection(YAML.load(File.read(File.join('config','database.yml'))))
  ActiveRecord::Migrator.migrate("db/migrate/", ENV["VERSION"] ? ENV["VERSION"].to_i : nil )
end
