require 'redis-lock'

class Ticket < ActiveRecord::Base
  belongs_to :requestor, :class_name => "User"
  belongs_to :submitter, :class_name => "User"
  belongs_to :assignee, :class_name => "User"
  belongs_to :organization
  belongs_to :group
  has_many :events, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :satisfaction_ratings, dependent: :destroy
  has_many :value_changes, dependent: :destroy
  has_and_belongs_to_many :tags
  before_save :update_refresh
  
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
    newest_date = newest_date.to_i.to_s
    
    records = CLIENT.connection.send(
      'get',
      "exports/tickets.json?start_time=#{newest_date}"
    ).body["results"]
    
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
  
  def self.create_from_zendesk_id(id, add_tags=true)
    ticket = Ticket.find(id) if Ticket.exists?(id)
    ticket ||= self.new
    @is_new = ticket.id.nil?
    ticket.id = id
    
    # Importing data about the ticket
    ticket.import_fields_from_zendesk
    ticket.create_associated_users_and_organization
    
    # Adding new tags (if the ticket is new, and not closed)
    if @is_new && add_tags && !(ticket.status == "closed" || ticket.status == "Closed")
      ticket.apply_watch_accounts
      ticket.mark_new_accounts
      ticket.assign_account_manager 
    end 
    
    # Importing and Updating Tags
    ticket.update_tags
    
    ticket.save!
    
    # Import audits 
    ticket.import_audits
        
    return ticket
  end

  def ddi
    return nil unless organization
    return organization.name.sub(/^D/, "")
  end

  def update_tags
    if @zd_tags
      #Update Keizan
      self.tags.destroy_all
      self.tags = @zd_tags.map { |ztag| (Tag.find_by_name(ztag) || Tag.create(:name => ztag)) }
      
      #Update Zendesk
      if @zdtags_updated
        zt = CLIENT.tickets.find(self.id)
        zt.tags = (@zd_tags + zt.tags).map { |tag| tag.downcase }.uniq
        zt.save
      end
    end
  end
  
  def apply_watch_accounts
    import_fields_from_zendesk unless @zd_tags
    
    watch_accounts = WatchAccount.find_all_by_number(self.ddi)
    watch_accounts.each do |w|
      # First send notification emails 
      Pony.mail(
        to:       w.watch_account_type.notification_emails, 
        subject:  "[#{w.watch_account_type.name.upcase}] New Ticket for Account ##{self.ddi}",
        body:     "There has been a new ticket for the account ##{self.ddi} (#{w.name})\n\n\nDate: #{self.created_at}\nTicket Number: #{self.id}\nTicket Subject: #{self.subject}\nURL: https://rackspacecloud.zendesk.com/tickets/#{self.id}"
      ) if w.watch_account_type.notification_emails
	    
	    if w.watch_account_type.default_tags
  	    @zd_tags = (@zd_tags + w.watch_account_type.default_tags).map { |tag| tag.downcase }.uniq
  	    @zdtags_updated = true
  	  end
    end
  end

  def assign_account_manager
    import_fields_from_zendesk unless @zd_tags
    
    # We only round robin on 'futurezen' tickets
    return nil unless @zd_tags.include?("futurezen")
    
    am_tags = [
      ["mc_sgilmore","steven.gilmore@rackspace.com"],
      ["mc_bhertzing","bill.hertzing@rackspace.com"],
      ["mc_chersh","christine.hersh@rackspace.com"],
      ["mc_nguerrero","nathan.guerrero@rackspace.com"],
      ["mc_ssanchez","seth.sanchez@rackspace.com"],
      ["mc_dbradley","daytona.bradley@RACKSPACE.COM"],
      ["mc_mamato","michael.amato@rackspace.com"]
    ]

    assigned_tags = am_tags.map {|t| t[0] } + [
      "cloud_uk",
      "smb_marquee",
      "enterprise_marquee",
      "zdmover_moved",
      "mc_ampool",
      "hybrid_ent",
      "hybrid_smb",
      "mc_dcox",
      "mc_mspenn",
      "mc_sford"
    ]
    
    # We only round robin on tickets that include none of the exception tags listed above
    return nil if assigned_tags - @zd_tags != assigned_tags
    
    #Here, we start the actual round robin assignment
    raise RuntimeError, "Cannot assign round robin AM on ticket #{self.id} without an organization" unless organization
    
    redis = Redis.new
    
    unless redis.get("next_am_index")
      redis.set("next_am_index",0)
    end
    
    redis.lock_for_update("next_am_index") do
      next_am_index = redis.get("next_am_index").to_i
      
      organization.with_lock do
        # Assign the next round robin am
        wat = WatchAccountType.where(name: am_tags[next_am_index][0]).first
        raise RuntimeError, "Trying to assign AM #{am_tags[next_am_index][0]}, but there is no matching WatchAccountType" unless wat
        
        wa = WatchAccount.create!(watch_account_type_id: wat.id, number: self.ddi)
  	    apply_watch_accounts
  	      
        # increment next_am_index
        redis.set("next_am_index",(next_am_index + 1) % am_tags.size)
        
        # Mail notification
        Pony.mail(
          to:       ["jason.gignac@rackspace.com",am_tags[next_am_index][1]], 
          subject:  "[MANAGED] New Account for #{wa.watch_account_type.name}",
          body:     "The account #{self.ddi} has been assigned to the #{wa.watch_account_type.name} tag, via ticket #{self.id} (URL: https://rackspacecloud.zendesk.com/tickets/#{self.id})."
        )
      end
    end
  end
  
  def mark_new_accounts
    if HmdbAccount.find(self.ddi).new_account?
      import_fields_from_zendesk unless @zd_tags
      @zd_tags = (@zd_tags + ["cloud_launch"]).uniq
    end
  end
  
  def import_audits
    audits = {}
    zd_audits = JSON.parse(CLIENT.connection.send('get',"tickets/#{id}/audits.json").body["audits"].to_json)
    zd_audits.each { |a| a["events"].each { |e| audits[a] ||= []; audits[a] << e}}
    audits.each { |a,events| events.each { |e| Event.create_from_zendesk_objects(event: e, audit: a, ticket: self)}}
  end
  
  def import_fields_from_zendesk
    data = JSON.parse(CLIENT.tickets.find(id).attributes["ticket"].to_json)
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
      self.update_attribute(attr, (data[attr.to_s]))
    end
    
    # Dates must be set by this method or the Zendesk plugin messes up the timezones
    self.due_at = data["due_at"]
    self.created_at = data["created_at"]
    self.updated_at = data["updated_at"]
    
    # The only part of Via that we want is the channel
    via = data["via"] ? data["via"]["channel"] : nil
    
    # Custom Fields
    data["fields"].each do |field_data|
      self.update_attribute(CUSTOM_FIELD_MAPS[field_data["id"].to_i], field_data["value"]) if CUSTOM_FIELD_MAPS[field_data["id"].to_i]
    end
    @zd_tags = data["tags"]
  end
  
  def update_refresh
    self.refreshed_at = DateTime.now
  end
  
  def create_associated_users_and_organization
    User.create_from_zendesk_object(CLIENT.users.find(self.requestor_id)) if self.requestor_id && !User.exists?(self.requestor_id)
    User.create_from_zendesk_object(CLIENT.users.find(self.submitter_id)) if self.submitter_id && !User.exists?(self.submitter_id)
    User.create_from_zendesk_object(CLIENT.users.find(self.assignee_id)) if self.assignee_id && !User.exists?(self.assignee_id)
    Organization.create_from_zendesk_object(CLIENT.organizations.find(self.organization_id)) if self.organization_id && !Organization.exists?(self.organization_id)
    Group.create_from_zendesk_object(CLIENT.groups.find(self.group_id)) if self.group_id && !Group.exists?(self.group_id)
  end
end
