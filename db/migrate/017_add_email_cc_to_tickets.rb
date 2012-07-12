class AddEmailCcToTickets < ActiveRecord::Migration
  def self.up
    add_column :tickets, :email_cc, :string
  end
  def self.down
    remove_column :tickets, :email_cc
  end
end
