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
    115033 => :email_cc, 
    115034 => :internal_account_information,
    115035 => :internal_queues,
    
    438039 => :location,
    500089 => :notify_customer,
    20782023 => :riid
  }
  
  def self.update(newest_date = nil)
    newest_date ||= Event.maximum(:created_at)
    newest_date = DateTime.now - 5.minutes unless DateTime.now - 5.minutes > newest_date
    
    result = CLIENT.connection.send('get',"exports/tickets.json?start_time=" + newest_date.to_i.to_s)
    records = result.body["results"]
    until records.empty?
      records.map do |res| 
        unless res.nil?
          raw_data = res.to_json
          REDIS.set("keizan__cache__ticket__#{res["id"]}",nil)
          REDIS.set("keizan__cache__ticket__#{res["id"]}__audits",nil)
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
  
  def self.create_from_zendesk_id(id, notify=true)
    ticket = Ticket.find(id) if Ticket.exists?(id)
    ticket ||= self.new
    is_new = ticket.id.nil?
 
    data = cached_ticket_data_for(id)
    # Directly Translated Fields
    attrs = [
      :id, 
      :ticket_type, 
      :subject, 
      :priority, 
      :status, 
      :requestor_id, 
      :submitter_id, 
      :assignee_id, 
      :organization_id, 
      :group_id, 
      :forum_topic_id, 
      :problem_id, 
      :has_incidents
    ]
    attrs.each do |attr|
      ticket.update_attribute(attr, (data[attr.to_s]))
    end
    ticket.due_at = data["due_at"]
    ticket.created_at = data["created_at"]
    ticket.updated_at = data["updated_at"]
    ticket.via = data["via"] ? data["via"]["channel"] : nil
    
    # Custom Fields
    data["fields"].each do |field_data|
      ticket.update_attribute(CUSTOM_FIELD_MAPS[field_data["id"].to_i], field_data["value"]) if CUSTOM_FIELD_MAPS[field_data["id"].to_i]
    end
    
    # Tags
    data["tags"].each { |ztag| 
      tags = ticket.tags
      tags << (Tag.find_by_name(ztag) || Tag.create(:name => ztag))
      ticket.tags = tags
    }
  
    ticket.save!
    
    # Events
    #zt.audits.each { |a| debugger; a.events.each { |e| Event.create_from_zendesk_objects(event: e, audit: a, ticket: ticket) } }
    audits = {}
    ticket.cached_audits.each { |a| a["events"].each { |e| audits[a] ||= []; audits[a] << e}}
    audits.each { |a,events| events.each { |e| Event.create_from_zendesk_objects(event: e, audit: a, ticket: ticket)}}
    # Uncached Associated Objects
    User.create_from_zendesk_object(CLIENT.users.find(ticket.requestor_id)) if ticket.requestor_id && !User.exists?(ticket.requestor_id)
    User.create_from_zendesk_object(CLIENT.users.find(ticket.submitter_id)) if ticket.submitter_id && !User.exists?(ticket.submitter_id)
    User.create_from_zendesk_object(CLIENT.users.find(ticket.assignee_id)) if ticket.assignee_id && !User.exists?(ticket.assignee_id)
    Organization.create_from_zendesk_object(CLIENT.organizations.find(ticket.organization_id)) if ticket.organization_id && !Organization.exists?(ticket.organization_id)
    Group.create_from_zendesk_object(CLIENT.groups.find(ticket.group_id)) if ticket.group_id && !Group.exists?(ticket.group_id)
    ticket.notify_on_major_accounts if is_new && notify

    ticket.assign_account_manager
    
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
	      tag_array = tags.map { |t| t.name }
	      default_tags = w.watch_account_type.default_tags
        if (default_tags & tag_array) != default_tags
          zt = CLIENT.tickets.find(self.id)
          tags = zt.tags
  	      tags = tags + default_tags
          zt.tags = tags
          zt.save
	        default_tags.each { |t| 
  	        self.tags << (Tag.find_by_name(t.downcase) || Tag.create(:name => t.downcase)) unless self.tags.include? t.downcase 
  	      }
	        self.save
        end
      end
    end
  end

  def assign_account_manager
    am_tags = [
      ["MC_SGilmore","steven.gilmore@rackspace.com"],
      ["MC_BHertzing","bill.hertzing@rackspace.com"],
      ["MC_CHersh","christine.hersh@rackspace.com"],
      ["MC_NGuerrero","nathan.guerrero@rackspace.com"],
      ["MC_SSanchez","seth.sanchez@rackspace.com"],
      ["MC_DBradley","daytona.bradley@RACKSPACE.COM"]
    ]
    assigned_tags = am_tags + ["smb_marquee","enterprise_marquee","zdmover_moved"]
    redis = Redis.new
    
    unless redis.get("next_am_index")
      redis.set("next_am_index",0)
    end
    
    next_am_index = redis.get("next_am_index").to_i
    
    if self.tags.map { |tag| tag.name }.include?("managed_service")
      if (self.tags.map { |tag| tag.name } & assigned_tags).empty?
        # Assign the next round robin am
        wat = WatchAccountType.where(name: am_tags[next_am_index][0]).first
        wat ||= WatchAccountType.create(name: am_tags[next_am_index][0], default_tags: [am_tags[next_am_index]])
        wa = WatchAccount.create(watch_account_type_id: wat.id, number: self.ddi)
        self.notify_on_major_accounts()
        
        # increment next_am_index
        redis.set("next_am_index",(next_am_index + 1) % am_tags.size)
        
        # assign to new
        u = User.where(email: am_tags[next_am_index][1]).first
        zt = CLIENT.tickets.find(self.id)
        zt.assignee_id = u.id
        zt.save
        
        
        Pony.mail(
          to:       "jason.gignac@rackspace.com", 
          subject:  "[MANAGED] New Account for #{wat.name}",
          body:     "The account #{self.ddi} has been assigned to #{wat.name}, through ticket #{self.id}"
        )
      end
    end
  end
  
  def self.cached_ticket_data_for(id)
    #raw_data = REDIS.get("keizan__cache__ticket__#{id}")
    #unless raw_data
      raw_data = CLIENT.tickets.find(id).attributes["ticket"].to_json
    #  REDIS.set("keizan__cache__ticket__#{id}",raw_data)
    #  REDIS.set("keizan__cache__ticket__#{id}__audits",nil)
    #end
    return JSON.parse(raw_data)
  end
  def cached_audits
    #raw_data = REDIS.get("keizan__cache__ticket__#{id}__audits")
    #unless raw_data
      raw_data = CLIENT.connection.send('get',"tickets/#{id}/audits.json").body["audits"].to_json
      REDIS.set("keizan__cache__ticket__#{id}__audits",raw_data)
    #end
    return JSON.parse(raw_data)
  end
end
