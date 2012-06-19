class CreateValueChanges < ActiveRecord::Migration
  def self.up
    create_table :value_changes do |t|
      t.column :id, :integer, :limit => 8
      t.column :field_name, :string
      t.column :value, :text
      t.column :old_value, :text
      t.column :new_entry, :boolean
      t.column :submitted_at, :datetime
      t.column :ticket_id, :integer, :limit => 8
    end
  end
  def self.down
    drop_table :value_changes
  end
end