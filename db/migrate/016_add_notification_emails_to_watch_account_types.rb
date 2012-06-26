class AddNotificationEmailsToWatchAccountTypes < ActiveRecord::Migration
  def self.up
    add_column :watch_account_types, :notification_emails, :text
  end

  def self.down
    remove_column :watch_account_types, :notification_emails
  end
end