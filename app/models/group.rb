class Group < ActiveRecord::Base
  has_many :organizations
  has_many :tickets
  
  def self.reload_all
    CLIENT.groups.each { |group| g = Group.create_from_zendesk_object(group) }
  end
  
  def self.create_from_zendesk_object(zg)
    g = Group.find(zg.id) if Group.exists?(zg.id)
    g ||= Group.new
    attrs = [:id, :name, :created_at, :updated_at, :deleted]
    attrs.each do |attr|
      g.send( (attr.to_s + "="), (zg.send attr))
    end
    g.save!
    return g
  end
end