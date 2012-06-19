class CreateGroups < ActiveRecord::Migration
  def self.up
    create_table :groups do |t|
      t.column :id, :integer, :limit => 32
      t.column :name, :string
      t.column :deleted, :boolean
      t.column :created_at, :datetime
      t.column :updated_at, :datetime
    end
  end
  
  def self.down
    drop_table :groups
  end
end