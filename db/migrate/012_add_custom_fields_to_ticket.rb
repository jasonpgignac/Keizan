class AddCustomFieldsToTicket < ActiveRecord::Migration
  def self.up
    add_column :tickets, :account_type, :string
    add_column :tickets, :ticket_category, :string
    add_column :tickets, :technology, :string
    add_column :tickets, :product_details, :text
    
    add_column :tickets, :internal_account_information, :text
    add_column :tickets, :internal_queues, :text
    
    add_column :tickets, :location, :string
    add_column :tickets, :notify_customer, :boolean
  end
  def self.down
    remove_column :tickets, :account_type
    remove_column :tickets, :ticket_category
    remove_column :tickets, :technology
    remove_column :tickets, :product_details
    
    remove_column :tickets, :internal_account_information
    remove_column :tickets, :internal_queues
    
    remove_column :tickets, :location
    remove_column :tickets, :notify_customer
  end
end