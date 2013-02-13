class AddGroupAssociationToWatchAccountTypes < ActiveRecord::Migration
  def self.up
    add_column :watch_account_types, :team_id, :integer
  end
  def self.down
    remove_column :watch_account_types, :team_id
  end
end
