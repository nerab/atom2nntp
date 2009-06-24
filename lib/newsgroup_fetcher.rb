require 'fetcher'
require 'rexml/document'
include REXML

class NewsgroupFetcher < Fetcher
    def self.create_newsgroup(url)
      atom = self.read(url)

      newsgroup = Newsgroup.new
      newsgroup.feed_url = url
      newsgroup.title          = Newsgroup.canonical_group_name(self.text(atom, "//feed/title"))
      newsgroup.subtitle       = self.text(atom, "//feed/subtitle")
      
      # TODO Does not work yet. Maybe REXML has a different way of coping with XPath?
      newsgroup.alternate_link = XPath.first(atom, "//feed/link[@rel='alternate']/@href")
      
      newsgroup.icon_url       = self.text(atom, "//feed/icon")
      newsgroup.updated        = self.text(atom, "//feed/updated")
      newsgroup.generator      = self.text(atom, "//feed/generator")    
      
      newsgroup.save!
      newsgroup
    end

private

  def self.text(atom, xpath)
    result = XPath.match(atom, xpath)
    
    if !result.nil? && !result.first.nil?
      result.first.text
    else
      ""
    end
  end
end
