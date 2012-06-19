class Comment < ActiveRecord::Base
  belongs_to :author, :class_name => "User"
  belongs_to :ticket
  has_many :events
  
  def self.create_from_zendesk_objects(objects)
    ze = objects[:event]
    za = objects[:audit]
    zt = objects[:ticket]
    c = Comment.new
    c.author_id = za.author_id
    c.text = ze.body
    c.public = ze.public
    c.ticket_id = zt.id
    c.created_at = za.created_at
    c.modified_at = za.created_at
    c.save!
    return c
  end
end