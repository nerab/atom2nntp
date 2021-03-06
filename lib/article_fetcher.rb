require 'rexml/document'
require 'fetcher'

include REXML

class ArticleFetcher < Fetcher
    def self.update(group)
      XPath.match(self.read(group.feed_url), "//feed/entry").each{|entry|
          link = XPath.match(entry, "link").first.attribute("href").to_s
          lp = LinkParser.new(group, link)
          message_id = lp.message_id
          thread_id = lp.thread_id if lp.message_id != lp.thread_id

          content = Document.new("<content>#{entry.get_elements("content").first.text}</content>")
          body = XPath.match(content, "content/p[2]").to_s
          
          if Article.find_by_message_id(message_id).nil?
            group.articles.create!(:link       => link,
                                   :message_id => message_id,
                                   :date       => DateTime.strptime(XPath.match(entry, "published").first.text),
                                   :from       => XPath.match(entry, "author/name").first.text,
                                   :subject    => XPath.match(entry, "title").first.text.gsub(/^Reply to /, "Re: "),
                                   :references => thread_id,
                                   :body       => body
                                  )
          end
      }
    end
end

