class AddRiidToTickets < ActiveRecord::Migration
  def self.up
    add_column :tickets, :riid, :string
  end
  def self.down
    remove_column :tickets, :riid_cc
  end
end
