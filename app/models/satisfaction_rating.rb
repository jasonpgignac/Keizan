class SatisfactionRating < ActiveRecord::Base
  belongs_to :assignee, :class_name => "User"
  belongs_to :ticket
  has_one :event
end
2107853781