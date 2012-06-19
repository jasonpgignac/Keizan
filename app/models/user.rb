class User < ActiveRecord::Base
  has_many :requested_tickets, :class_name => "Ticket", :foreign_key => "requestor_id"
  has_many :submitted_tickets, :class_name => "Ticket", :foreign_key => "submitter_id"
  has_many :assigned_tickets, :class_name => "Ticket", :foreign_key => "assignee_id"
  has_many :authored_events, :class_name => "Event", :foreign_key => "author_id"
  has_many :assigned_satisfaction_ratings, :class_name => "SatisfactionRating", :foreign_key => "assignee_id"
  belongs_to :organization
  
  def self.reload_all
    users = CLIENT.users
    until users.empty? do
      users.each { |user| u = User.create_from_zendesk_object(user) }
      users = CLIENT.users.next
    end
  end
  
  def self.create_from_zendesk_object(zu)
    u = User.find(zu.id) if User.exists?(zu.id)
    u ||= User.new
    
    attrs = [:id, :name, :created_at, :updated_at, :active, :verified, :time_zone, :last_login_at, :email, 
        :phone, :signature, :details, :notes, :organization_id, :role, :customer_role_id, :moderator, 
        :ticket_restriction, :only_private_comments, :suspended]
    attrs.each do |attr|
      u.send( (attr.to_s + "="), (zu.send attr))
    end
    u.save!
    return u
  end
end