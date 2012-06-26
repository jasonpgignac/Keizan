class CreateWatchAccountTypes < ActiveRecord::Migration
  def self.up
    create_table :watch_account_types do |t|
      t.string :name
      t.string :default_tags
    end
  end

  def self.down
    drop_table :watch_account_types
  end
end
