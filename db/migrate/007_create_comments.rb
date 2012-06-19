class CreateComments < ActiveRecord::Migration
  def self.up
    create_table :comments do |t|
      t.column :id, :integer, :limit => 32
      t.column :author_id, :integer
      t.column :text, :text
      t.column :public, :boolean
      t.column :ticket_id, :integer, :limit => 32
      t.column :created_at, :datetime
      t.column :modified_at, :datetime
    end
  end
  def self.down
    drop_table :comments
  end
end