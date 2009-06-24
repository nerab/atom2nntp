require 'rexml/document'
include REXML
require 'fetcher'
require 'rfc822_article'

class ArticleFetcher < Fetcher
    def self.articles(group)
      XPath.match(self.read(group.feed_url), "//feed/entry").each{|entry|
          rfc = RFC822Article.new(group, entry)          
          if Article.find_by_message_id(rfc.message_id).nil?
            a = group.articles.create!(:link => rfc.link,
                                       :message_id => rfc.message_id,
                                       :date => rfc.date,
                                       :from => rfc.from,
                                       :subject => rfc.subject,
                                       :references => rfc.references,
                                       :body => rfc.body)
          end
      }
      group.articles
    end
end
