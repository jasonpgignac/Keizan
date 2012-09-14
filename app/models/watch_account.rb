require 'xmlsimple'
require 'net/http'
class WatchAccount < ActiveRecord::Base
  belongs_to :watch_account_type
  validate :record_is_unique
  
  def account_manager
    url = URI.parse("#{ configuration["url"] }/support-accounts/C#{number}/roleassignments")
    request = Net::HTTP::Get.new(url.path)
    request.add_field("X-Auth-Token", auth_token)
    
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    
    response = http.start { |http| http.request(request) }
    XmlSimple.xml_in(response.body)
  end
  
  def update_cmdb
    puts "Updating watch account #{id}"
    set_account_manager if watch_account_type.is_account_manager
    set_cmdb_group if watch_account_type.is_team
  end
  def set_account_manager
    url = URI.parse("#{ configuration["url"] }/support-accounts/C#{number}/roleassignments/AccountManager/users/#{watch_account_type.cmdb_tag}")
    request = Net::HTTP::Put.new(url.path)
    request.content_type = 'application/xml'
    request.add_field("X-Auth-Token", auth_token)
    
    response = Net::HTTP.start(url.host, url.port, :use_ssl => true, :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
      http.request(request)
    end
    response.body

  end
  
  def cmdb_record
    url = URI.parse("#{ configuration["url"] }/support-accounts/C#{number}")
    request = Net::HTTP::Get.new(url.path)
    request.add_field("X-Auth-Token", auth_token)
    
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    
    response = http.start { |http| http.request(request) }
    XmlSimple.xml_in(response.body)
  end
  
  def set_cmdb_group
    url = URI.parse("#{ configuration["url"] }/support-accounts/C#{number}")
    request = Net::HTTP::Put.new(url.path)
    request.content_type = 'application/xml'
    request.add_field("X-Auth-Token", auth_token)
    request.body ="<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" + 
      "<support-account xmlns=\"http://configuration-item.api.rackspacecloud.com/v1\" id=\"C#{number}\">" + 
      "  <name>#{ cmdb_record["name"][0] }</name>" + 
      "  <service-level>#{ cmdb_record["service-level"][0] }</service-level>" + 
      "  <RCN>#{ cmdb_record["RCN"][0] }</RCN>" + 
      "  <team>#{ watch_account_type.cmdb_tag }</team>" + 
      "</support-account>"
    
    response = Net::HTTP.start(url.host, url.port, :use_ssl => true, :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
      http.request(request)
    end
    response.body
  end
  
  def auth_token
    self.class.auth_token
  end
  
  def self.auth_token
    return @auth_token if @auth_token
    url = URI.parse("#{ configuration["auth_url"] }/tokens")
    request = Net::HTTP::Post.new(url.path)
    request.content_type = 'application/json'
    request.body = {rackerCredentials: configuration["rackerCredentials"]}.to_json
    
    response = Net::HTTP.start(url.host, url.port, :use_ssl => true, :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
      http.request(request)
    end
    @auth_token = JSON.parse(response.body)["auth"]["access_token"]["id"]
  end
  
  def record_is_unique
    if watch_account_type.is_account_manager
      dupes = self.class.where(number: number).delete_if { |wa| (!wa.watch_account_type.is_account_manager) || wa.id == id }
      errors.add(:number, "is not unique - there is already an account manager for this account") unless dupes.size == 0
    elsif watch_account_type.is_team
      dupes = self.class.where(number: number).delete_if { |wa| (!wa.watch_account_type.is_team) || wa.id == id }
      errors.add(:number, "is not unique - there is already a team for this account") unless dupes.size == 0
    end
  end
  
  def configuration
    self.class.configuration
  end
  
  def self.configuration
    return @configuration ||= YAML::load(File.open(File.join(File.dirname(__FILE__),'..','..','config','cmdb.yml')))

  end
end
