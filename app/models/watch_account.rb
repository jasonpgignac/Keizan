require 'xmlsimple'
require 'net/http'
class WatchAccount < ActiveRecord::Base
  belongs_to :watch_account_type
  
  def cmdb_record
    url = URI.parse("https://staging.configuration-item.api.rackspacecloud.com:443/v1/ci/support-accounts/C#{number}")
    request = Net::HTTP::Get.new(url.path)
    
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    
    response = http.start { |http| http.request(request) }
    XmlSimple.xml_in(response.body)
    
  end
  
  def set_cmdb_group
    url = URI.parse("https://staging.configuration-item.api.rackspacecloud.com:443/v1/ci/support-accounts/C#{number}")
    request = Net::HTTP::Put.new(url.path)
    request.content_type = 'application/xml'
    request.body ="<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" + 
      "<support-account xmlns=\"http://configuration-item.api.rackspacecloud.com/v1\" id=\"C#{number}\">" + 
      "  <name>#{ cmdb_record["name"][0] }</name>" + 
      "  <service-level>#{ cmdb_record["service-level"][0] }</service-level>" + 
      "  <RCN>#{ cmdb_record["RCN"][0] }</RCN>" + 
      "  <team>#{ watch_account_type.name }</team>" + 
      "</support-account>"
    
    puts request.body
    
    response = Net::HTTP.start(url.host, url.port, :use_ssl => true, :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
      http.request(request)
    end
    XmlSimple.xml_in(response.body)
  end
end
