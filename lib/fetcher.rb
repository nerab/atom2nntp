require 'net/http'
require 'uri'
require 'rexml/document'
include REXML

class Fetcher
  @@feed_cache = {}
  @@logger = ActiveRecord::Base.logger || Logger.new(STDOUT)
  
  #
  # Implements conditional GETs, see http://fishbowl.pastiche.org/2002/10/21/http_conditional_get_for_rss_hackers/
  #
  def self.read(url)
    # Has this url ever been read?
    if !@@feed_cache.has_key?(url)
      @@feed_cache[url] = {}
    end

    res = get_http(url, @@feed_cache[url][:last_modified])
    
    case res
      when Net::HTTPNotModified then
          @@logger.info "#{Time.now} - Feed at #{url} was not updated since #{@@feed_cache[url][:last_modified]}"
      when Net::HTTPSuccess then
          @@logger.info "#{Time.now} - Feed at #{url} was updated. New value for 'Last-Modified' is #{res['Last-Modified']}"
          @@feed_cache[url][:last_modified] = res['Last-Modified']
          @@feed_cache[url][:body] = res.body
    end
  
    return Document.new(@@feed_cache[url][:body])
  end

private
  def self.get_http(p_url, last_modified)
      url = URI.parse(p_url)
        
      res = Net::HTTP.start(url.host, url.port) {|http|
        # http.set_debug_output $stdout
          
        request = Net::HTTP::Get.new(url.request_uri)
        request.add_field 'User-Agent', 'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-GB; rv:1.8.1.16) Gecko/20080702 Firefox/2.0.0.16'
        request.add_field('If-Modified-Since', last_modified) if last_modified        
        http.request(request)
      }
      res
  end
end
