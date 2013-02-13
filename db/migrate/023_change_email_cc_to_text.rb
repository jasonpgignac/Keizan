class ChangeEmailCcToText < ActiveRecord::Migration
  def self.up
    change_column :tickets, :email_cc, :text
  end
  def self.down
    change_column :tickets, :email_cc, :string
  end
end