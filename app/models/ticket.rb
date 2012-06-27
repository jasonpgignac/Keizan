class Ticket < ActiveRecord::Base
  belongs_to :requestor, :class_name => "User"
  belongs_to :submitter, :class_name => "User"
  belongs_to :assignee, :class_name => "User"
  belongs_to :organization
  belongs_to :group
  has_many :events
  has_many :comments
  has_many :satisfaction_ratings
  has_many :value_changes
  has_and_belongs_to_many :tags
  
  CUSTOM_FIELD_MAPS = {
    115026 => :account_type,
    115030 => :ticket_category,
    115031 => :technology,
    115032 => :product_details,
    
    115034 => :internal_account_information,
    115035 => :internal_queues,
    
    438039 => :location,
    500089 => :notify_customer,
  }
  
  def self.reload_all(starting_page=1)
    tickets = CLIENT.tickets.page(starting_page)
    
    until tickets.empty? do
      tickets.each { |ticket| t = Ticket.create_from_zendesk_object(ticket, false) }
      tickets = CLIENT.tickets.page(CLIENT.tickets.next)
    end
  end
  
  def self.update(newest_date = nil)
    newest_date ||= Event.maximum(:created_at)
    newest_date = DateTime.now - 5.minutes unless DateTime.now - 5.minutes > newest_date
    
    result = CLIENT.connection.send('get',"exports/tickets.json?start_time=" + newest_date.to_i.to_s)
    records = result.body["results"]
    until records.empty?
      records.map do |res| 
        unless res.nil?
          Resque.enqueue(TicketUpdater, res["id"])
        end
      end
      begin
        result = CLIENT.connection.send('get',result.body["next_page"])
        records = result.body["results"]
      rescue Faraday::Error::ParsingError, "757: unexpected token at 'Too recent start_time. Use a start_time older than 5 minutes'"
        records = []
      end
    end
  end
  
  def self.create_from_zendesk_object(zt, notify=true)
    ticket = Ticket.find(zt.id) if Ticket.exists?(zt.id)
    ticket ||= self.new
    is_new = ticket.id.nil?
 
    # Directly Translated Fields
    attrs = [:id, :ticket_type, :subject, :priority, :status, :requestor_id, :submitter_id, :assignee_id, 
      :organization_id, :group_id, :forum_topic_id, :problem_id, :has_incidents]
    attrs.each do |attr|
      ticket.update_attribute(attr, (zt.send attr))
    end
    ticket.due_at = zt.due_at
    ticket.created_at = zt.created_at
    ticket.updated_at = zt.updated_at
    ticket.via = zt.via ? zt.via.channel : nil
    
    # Custom Fields
    zt.fields.each do |field_data|
      ticket.update_attribute(CUSTOM_FIELD_MAPS[field_data["id"].to_i], field_data["value"]) if CUSTOM_FIELD_MAPS[field_data["id"].to_i]
    end
    
    # Tags
    zt.tags.each { |ztag| ticket.tags << (Tag.find_by_name(ztag) || Tag.create(:name => ztag)) }
  
    ticket.save!
    
    # Events
    #zt.audits.each { |a| debugger; a.events.each { |e| Event.create_from_zendesk_objects(event: e, audit: a, ticket: ticket) } }
    audits = {}
    zt.audits.each { |a| a.events.each { |e| audits[a] ||= []; audits[a] << e}}
    audits.each { |a,events| events.each { |e| Event.create_from_zendesk_objects(event: e, audit: a, ticket: ticket)}}
    # Uncached Associated Objects
    User.create_from_zendesk_object(CLIENT.users.find(ticket.requestor_id)) if ticket.requestor_id && !User.exists?(ticket.requestor_id)
    User.create_from_zendesk_object(CLIENT.users.find(ticket.submitter_id)) if ticket.submitter_id && !User.exists?(ticket.submitter_id)
    User.create_from_zendesk_object(CLIENT.users.find(ticket.assignee_id)) if ticket.assignee_id && !User.exists?(ticket.assignee_id)
    Organization.create_from_zendesk_object(CLIENT.organizations.find(ticket.organization_id)) if ticket.organization_id && !Organization.exists?(ticket.organization_id)
    Group.create_from_zendesk_object(CLIENT.groups.find(ticket.group_id)) if ticket.group_id && !Group.exists?(ticket.group_id)
    ticket.notify_on_major_accounts if is_new && notify

    return ticket
  end

  def ddi
    return nil unless organization
    return organization.name.sub(/^D/, "")
  end

  def notify_on_major_accounts
    watch_accounts = WatchAccount.find_all_by_number(self.ddi)
    unless watch_accounts.empty?
      watch_accounts.each do |w|
        if w.watch_account_type.notification_emails 
          Pony.mail(
            to:       w.watch_account_type.notification_emails, 
            subject:  "[#{w.watch_account_type.name.upcase}] New Ticket for Account ##{self.ddi}",
            body:     "There has been a new ticket for the account ##{self.ddi} (#{w.name})\n\n\nDate: #{self.created_at}\nTicket Number: #{self.id}\nTicket Subject: #{self.subject}\nURL: https://rackspacecloud.zendesk.com/tickets/#{self.id}"
	  )
	end
        zt = CLIENT.tickets.find(self.id)
        if w.watch_account_type.default_tags
          tags = zt.tags
  	  tags = tags + w.watch_account_type.default_tags
          zt.tags = tags
          zt.save
	  w.watch_account_type.default_tags.each { |t| self.tags << (Tag.find_by_name(t.downcase) || Tag.create(:name => t.downcase)) unless self.tags.include? t.downcase }
	  self.save
        end
      end
    end
  end

end
