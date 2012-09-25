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
    @connection ||= HMDBRecord.connection
  end
  def self.table
    @table ||= Arel::Table.new(:ACT_Account,HMDBRecord)
  end
  
  def self.find(id)
    sql = table.project('*').where( table[:Id].eq id ).to_sql
    d = self.new
    d.data = connection.exec_query(sql).rows[0] || {}
    return d unless d.data.nil?
  end
  
  def id
    data[0]
  end
  
  def creation_date
    data[3]
  end
  
  def new_account?
    self.creation_date > DateTime.now - 1.month
  end
end

class HMDBRecord < ActiveRecord::Base  
end

HMDBRecord.establish_connection YAML.load_file("config/hmdb.yml")