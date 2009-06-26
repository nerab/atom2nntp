require 'open-uri'
require 'rexml/document'
include REXML

feed = Document.new(open("http://api.flickr.com/services/feeds/groups_discuss.gne?id=71917374@N00&lang=en-us&format=atom").read)

XPath.match(feed, "//feed/entry").each{|entry|
  content = Document.new("<content>#{entry.get_elements("content").first.text}</content>")
  
  html = XPath.match(content, "content/p[2]").to_s
  p html
}

