class CreateUsers < ActiveRecord::Migration
  def self.up
    create_table :users do |t|
      t.column :id, :integer, :limit => 32
      t.column :name, :string
      t.column :created_at, :datetime
      t.column :updated_at, :datetime
      t.column :active, :boolean
      t.column :verified, :boolean
      t.column :time_zone, :string
      t.column :last_login_at, :datetime
      t.column :email, :string
      t.column :phone, :string
      t.column :signature, :text
      t.column :details, :text
      t.column :notes, :text
      t.column :organization_id, :integer, :limit => 32
      t.column :role, :string
      t.column :customer_role_id, :integer, :limit => 32
      t.column :moderator, :boolean
      t.column :ticket_restriction, :string
      t.column :only_private_comments, :boolean
      t.column :suspended, :boolean
    end
  end
  
  def self.down
    drop_table :users
  end
end