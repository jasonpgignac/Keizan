class Organization < ActiveRecord::Base
  has_many :tickets
  has_many :users
  belongs_to :group
  
  def self.reload_all
    orgs = CLIENT.organizations
    until orgs.empty? do
      orgs.each { |org| o = Organization.create_from_zendesk_object(org) }
      orgs = CLIENT.organizations.next
    end
  end
  
  def self.create_from_zendesk_object(zo)
    o = Organization.find(zo.id) if Organization.exists?(zo.id)
    o ||= Organization.new
    attrs = [:id, :created_at, :updated_at, :details, :notes, :group_id, :shared_tickets, :shared_comments]
    attrs.each do |attr|
      o.send( (attr.to_s + "="), (zo.send attr))
    end
    o.name = zo.name.sub(/^D/,"")
    o.save!
    return o
  end
end