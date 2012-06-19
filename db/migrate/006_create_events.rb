class CreateEvents < ActiveRecord::Migration
  def self.up
    create_table :events do |t|
      t.integer :id, :limit => 32
      t.string :event_type
      t.text :body
      t.boolean :public
      t.integer :ticket_id, :limit => 32
      t.integer :value_change_id, :limit => 32
      t.integer :comment_id, :limit => 32
      t.integer :satisfaction_rating_id, :limit => 32
      t.datetime :created_at, :datetime
      t.integer :author_id, :limit => 32
    end
  end
  def self.down
    drop_table :events
  end
end