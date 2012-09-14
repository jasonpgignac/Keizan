class AddCmdbTagToAccountTypes < ActiveRecord::Migration
  def self.up
    add_column :watch_account_types, :cmdb_tag, :string
  end
  def self.down
    remove_column :watch_account_types, :cmdb_tag, :string
  end
end
