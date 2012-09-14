class AddCmdbFieldsToWatchAccountTypes < ActiveRecord::Migration
  def self.up
    add_column :watch_account_types, :is_account_manager, :boolean
    add_column :watch_account_types, :is_team, :boolean
  end
  def self.down
    remove_column :watch_account_types, :is_account_number
    remove_column :watch_account_types, :is_team
  end
end
