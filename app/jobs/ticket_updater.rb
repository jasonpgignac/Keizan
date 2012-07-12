class TicketUpdater
  include Resque::Plugins::UniqueJob
  @queue = "keizan_updater"
  
  def self.perform(id)
    Ticket.create_from_zendesk_id(id)
  end
end