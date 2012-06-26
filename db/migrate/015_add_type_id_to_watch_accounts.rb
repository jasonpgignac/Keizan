class AddTypeIdToWatchAccounts < ActiveRecord::Migration
  def self.up
    add_column :watch_accounts, :watch_account_type_id, :string
  end
  
  def self.down
    drop_column :watch_accounts, :watch_account_type_id
  end
end