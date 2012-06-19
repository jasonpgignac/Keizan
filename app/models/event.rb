class Event < ActiveRecord::Base
  belongs_to :ticket
  belongs_to :author, :class_name => "User"
  
  belongs_to :value_change, :dependent => :destroy
  belongs_to :comment, :dependent => :destroy
  belongs_to :satisfaction_rating, :dependent => :destroy
  
  BODY_FORMATTERS = {
    Comment:               lambda { |e| "Added comment by #{e.author_id}" },
    VoiceComment:          lambda { |e| "Phone Comment submitted: #{e.data.to_s}" },
    CommentPrivacyChange:  lambda { |e| "Changed privacy of comment #{e.comment_id}" },
    Create:                lambda { |e| "Added the #{e.field_name} value to the record"},
    Change:                lambda { |e| "Altered the #{e.field_name} value on the record"},
    Notification:          lambda { |e| "Sent Notification to user(s) #{e.recipients.to_s}:\nSubject: #{e.subject}\nBody: #{e.body}" },
    Cc:                    lambda { |e| "Added user(s) #{e.recipients.to_s} as collaborators" },
    Error:                 lambda { |e| e.message.to_s },
    External:              lambda { |e| "Resource: #{e.resource}\nBody: #{e.body}\nSuccess: #{e.success}"},
    FacebookEvent:         lambda { |e| e.body },
    LogMeInTranscript:     lambda { |e| e.body },
    Push:                  lambda { |e| "Value: #{e.value}\nValue Reference: #{e.value_reference}" },
    SatisfactionRating:    lambda { |e| "User #{e.assignee_id} rec'd a score of #{e.score} with this comment:\n#{e.body}" },
    Tweet:                 lambda { |e| "Sent tweet to #{e.recipients.to_s}: #{e.body}" },
    SMS:                   lambda { |e| "Sent Text message to reciptient #{e.recipient_id} (#{e.phone_number}): #{e.body}" },
    TicketSharingEvent:    lambda { |e| "Agreement ID: #{e.agreement_id}, Action: #{e.shared}" }
  }
  
  def self.create_from_zendesk_objects(objects)
    ze = objects[:event]
    za = objects[:audit]
    zt = objects[:ticket]
    Event.find(ze.id).destroy if Event.exists?(ze.id)
    e = Event.new
    e.id = ze.id
    e.event_type = ze.type
    e.author_id = za.author_id
    e.created_at = za.created_at
    e.ticket_id = zt.id
    
    case ze.type
      when "Comment"
        e.comment_id = Comment.create_from_zendesk_objects(objects).id
      when "CommentPrivacyChange"
        comment = Event.find(ze.comment_id).comment
        comment.modified_at = za.created_at
        comment.public = ze.public
        comment.save!
        
        e.comment_id = comment.id
        e.public = ze.public
      when "Create", "Change"
        e.value_change_id = ValueChange.create_from_zendesk_objects(objects)
    end
    e.body = BODY_FORMATTERS[ze.type.to_sym].call(ze)
    e.save!
    return e
  end
end