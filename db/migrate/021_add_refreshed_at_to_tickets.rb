class AddRefreshedAtToTickets < ActiveRecord::Migration
  def self.up
    add_column :tickets, :refreshed_at, :datetime
  end
  def self.down
    remove_column :tickets, :refreshed_at
  end
end
