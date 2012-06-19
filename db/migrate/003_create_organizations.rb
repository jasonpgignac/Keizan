class CreateOrganizations < ActiveRecord::Migration
  def self.up
    create_table :organizations do |t|
      t.column :id, :integer, :limit => 32
      t.column :name, :string
      t.column :created_at, :datetime
      t.column :updated_at, :datetime
      t.column :details, :text
      t.column :notes, :text
      t.column :group_id, :integer, :limit => 32
      t.column :shared_tickets, :boolean
      t.column :shared_comments, :boolean
    end
  end
  
  def self.down
    drop_table :organizations
  end
end