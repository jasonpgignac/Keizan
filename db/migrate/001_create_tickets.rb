class CreateTickets < ActiveRecord::Migration
  def self.up
    create_table :tickets do |t|
      t.column :id, :integer, :limit => 32
      t.column :ticket_type, :string
      t.column :subject, :string
      t.column :priority, :string
      t.column :status, :string
      t.column :requestor_id, :integer, :limit => 32
      t.column :submitter_id, :integer, :limit => 32
      t.column :assignee_id, :integer, :limit => 32
      t.column :organization_id, :integer, :limit => 32
      t.column :group_id, :integer, :limit => 32
      t.column :forum_topic_id, :integer, :limit => 32
      t.column :problem_id, :integer, :limit => 32
      t.column :has_incidents, :boolean
      t.column :due_at, :datetime
      t.column :via, :string
      t.column :created_at, :datetime
      t.column :updated_at, :datetime
    end
  end

  def self.down
    drop_table :tickets
  end
end
