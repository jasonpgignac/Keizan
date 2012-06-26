class TicketUpdater
  @queue = "keizan_updater"
  
  def self.perform(id)
    Ticket.create_from_zendesk_object(CLIENT.tickets.find(id))
  end
end