class WatchAccountType < ActiveRecord::Base
  has_many :watch_accounts
  serialize :default_tags
  serialize :notification_emails
end
