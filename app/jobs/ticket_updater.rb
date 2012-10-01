
class TicketUpdater
  include Resque::Plugins::UniqueJob
  @queue = "keizan_updater"
  
  def self.perform(id,refresh=false)
    Ticket.find(id).destroy if refresh && Ticket.exists?(id)
    Ticket.create_from_zendesk_id(id)
  end
end