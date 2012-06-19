class CreateSatisfactionRatings < ActiveRecord::Migration
  def self.up
    create_table :satisfaction_ratings do |t|
      t.column :id, :integer, :limit => 32
      t.column :score, :integer
      t.column :assignee_id, :integer
      t.column :ticket_id, :integer, :limit => 32
      t.column :body, :string
      t.column :created_at, :datetime
    end
  end
  def self.down
    drop_table :satisfaction_ratings
  end
end

