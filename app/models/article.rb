require "html2text"

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
                                            :body => "<p>Synthetic parent. For the original, see <a href='#{lp.thread_url}'>#{lp.thread_url}</a><p>",
                                            :link => lp.thread_url,
                                            :date => a.date.beginning_of_day)
    end
    a.parent = parent
    
    # multipart boundary
    a.boundary = "Multipart_#{DateTime.now.to_s(:number)}_#{a.id}" # should be reasonably unique
    a.plaintext_body = HTML2Text.text(a.body)    
    a.save!
  }
  
  def head
      article = ""
      article << "Message-ID: #{message_id}" << "\r\n"
      article << "Date: #{date.to_time.rfc822}" << "\r\n"
      article << "From: #{from}" << " <atom2nntp@example.com>" << "\r\n"
      article << "Newsgroups: #{newsgroup.title}" << "\r\n"
      article << "Subject: #{subject}" << "\r\n"
      article << "References: #{references}" << "\r\n" if !references.nil?
      article << "MIME-Version: 1.0" << "\r\n"
      article << "Content-Type: multipart/mixed; boundary=\"#{boundary}\"" << "\r\n"
      article << "Content-Transfer-Encoding: 8bit" << "\r\n"
      article
  end
    
  def content
      article = head
      article << "\r\n"
      article << "This is a multipart message." << "\r\n" # preamble
      article << "\r\n"
      
      # html part
      article << "--#{boundary}" << "\r\n"
      article << "Content-Type: text/html; charset=utf-8" << "\r\n"
      article << "\r\n"
      article << body.to_s << "\r\n"
      article << "\r\n"
      
      # plaintext part
      article << "--#{boundary}" << "\r\n"
      article << "Content-Type: text/plain; charset=utf-8" << "\r\n"
      article << "\r\n"
      article << plaintext_body << "\r\n"
      article << "\r\n"
      
      # finishing
      article << "--#{boundary}--" << "\r\n"
      article << "\r\n"
      article << "End of message."  << "\r\n" # epilogue
      article << "\r\n"
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
  
  def previous
  end
  
  # Retrieves the next article within the thread. Assumes that ids are continuous.
  def next
    self.root.children.reject{|sibling| sibling.date <= self.date}.sort{|a,b| a.date <=> b.date}.first
  end
 
  def previous_thread
  end
    
  # Retrieves the first article in the next thread. Assumes that ids are continuous.
  def next_thread
    self.newsgroup.threads.reject{|sibling| sibling.date < self.date || sibling.id < self.id}.sort{|a,b| a.id <=> b.id}.first
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
