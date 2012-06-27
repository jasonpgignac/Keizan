class ValueChange < ActiveRecord::Base
  has_one :event
  belongs_to :ticket
  
  def self.create_from_zendesk_objects(objects)
    ze = objects[:event]
    za = objects[:audit]
    zt = objects[:ticket]
    
    vc = ValueChange.new
    field_name = ze.field_name.to_i.to_s == ze.field_name ? Ticket::CUSTOM_FIELD_MAPS[ze.field_name.to_i] : ze.field_name
    raise(RuntimeError, "Could not map #{ze.field_name} to a field") if field_name.nil?
    vc.field_name = field_name
    vc.value = ze.value
    vc.old_value = ze.previous_value
    vc.new_entry = (ze.type == "Create")
    vc.submitted_at = za.created_at
    vc.ticket_id = zt.id
    vc.save!
    return vc
  end
end