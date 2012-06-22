class CreateWatchAccounts < ActiveRecord::Migration
  def self.up
    create_table :watch_accounts do |t|
      t.string :name
      t.string :number
    end
  end
  def self.down
    drop_table :watch_accounts
  end
end
