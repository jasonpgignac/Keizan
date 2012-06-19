class ValueChange < ActiveRecord::Base
  has_one :event
  belongs_to :ticket
  
  def self.create_from_zendesk_objects(objects)
    ze = objects[:event]
    za = objects[:audit]
    zt = objects[:ticket]
    
    vc = ValueChange.new
    vc.field_name = ze.field_name
    vc.value = ze.value
    vc.old_value = ze.previous_value
    vc.new_entry = (ze.type == "Create")
    vc.submitted_at = za.created_at
    vc.ticket_id = zt.id
    vc.save!
    return vc
  end
end