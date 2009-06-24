class Article < ActiveRecord::Base
  belongs_to :newsgroup
  validates_uniqueness_of(:message_id)
  acts_as_tree :order => :date
  
  after_create{|a| 
    # Create synthetic parent if 'a' references an article we don't know yet
    parent = Article.find_by_message_id(a.references)
    if parent.nil? && !a.references.blank?
      logger.debug "creating synthetic parent for #{a.references} (in #{a.newsgroup.title})"
      lp = LinkParser.new(a.newsgroup, a.link)
      parent = a.newsgroup.articles.create!(:subject => a.subject.gsub(/^Re: /, ""), 
                                            :parent_id => nil, 
                                            :message_id => a.references, 
                                            :from => "unknown",
                                            :body => "Synthetic parent. For the original, see <a href='#{lp.thread_url}'>#{lp.thread_url}</a>",
                                            :link => lp.thread_url,
                                            :date => a.date.beginning_of_day)
    end
    a.parent = parent
    a.save!
  }
  
  def head
      article = ""
      article << "Message-ID: #{message_id}" << "\r\n"
      article << "Date: #{date.to_time.rfc822}" << "\r\n"
      article << "From: #{from}" << " <rss2news@example.com>" << "\r\n"
      article << "MIME-Version: 1.0" << "\r\n"
      article << "Newsgroups: #{newsgroup.title}" << "\r\n"
      article << "Subject: #{subject}" << "\r\n"
      article << "References: #{references}" << "\r\n" if !references.nil?
      article << "Content-Type: text/html; charset=UTF-8" << "\r\n"
      article << "Content-Transfer-Encoding: 8bit" << "\r\n"
      article << "Content-Base: #{link}" << "\r\n"
      article
  end
    
  def content
      article = head
      article << "\r\n"
      article << body.to_s
      article
  end

  ## Each line of output will be formatted with the article number,
  ## followed by each of the headers in the overview database or the
  ## article itself (when the data is not available in the overview
  ## database) for that article separated by a tab character.  The
  ## sequence of fields must be in this order: subject, author, date,
  ## message-id, references, byte count, and line count.
  def overview
    result = ""
    result << "#{untab(id)}\t"
    result << "#{untab(subject)}\t"
    result << "#{untab(from)}" << " <rss2news@example.com>" << "\t"
    result << "#{date.to_time.rfc822}\t"
    result << "#{message_id}\t"
    result << (references.nil? ? " \t" : "#{references}\t")
    result << "#{bytes(content)}\t"
    result << "#{lines(content)}"
    result
  end
  
private
  def bytes(str)
    size = 0
    str.each_byte {|c| size += 1 }
    size
  end
  
  def lines(str)
    str.split("\r\n").size
  end
  
  def untab(str)
    str.to_s.gsub(/(\r\n|\n\r|\n|\t)/, ' ')
  end
end
