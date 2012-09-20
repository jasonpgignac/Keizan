class HmdbAccount
  attr_accessor :data
  def self.configuration=(hash)
    @configuration = hash
  end
  def self.configuration
    @connection = nil
    @configuration
  end
  def self.connection
    @connection ||= PG::Connection.new(configuration)
  end
  
  def self.find(id)
    self.new(data: connection.exec("SELECT * FROM ACT_Account WHERE ID = #{id}"))
  end
end