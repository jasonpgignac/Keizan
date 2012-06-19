class CreateTicketsTags < ActiveRecord::Migration
  def self.up
    create_table :tags_tickets do |t|
      t.integer :tag_id
      t.integer :ticket_id
    end
  end
  def self.down
    drop_table :tags_tickets
  end
end