class CreateTags < ActiveRecord::Migration
  def self.up
    create_table :tags do |t|
      t.integer :id
      t.string :name
    end
  end
  def self.down
    drop_table :tags
  end
end