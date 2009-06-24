require 'date'
require 'activesupport'
require 'link_parser'
require 'rexml/document'
include REXML

# TODO Un-escape ".." to "."
# TODO Remove last line containing "."
class RFC822Article
  attr_reader :group, :link, :message_id, :date, :from, :subject, :references, :body

  #
  # makes a rfc822 article from a given atom entry
  #
  def initialize(group, entry = nil)
    if entry.nil?
      # parse the first param as rfc822 article string
      headers,@body = parse_rfc822(group)
      
      @group = Newsgroup.find_by_title(headers["Newsgroups"])
      @message_id = headers["Message-ID"]
      @date = headers["Date"]
      @from = headers["From"]
      @subject = headers["Subject"]
      @references = headers["References"]
      @content_type = headers["Content-Type"]
      @content_transfer_encoding = headers["Content-Transfer-Encoding"]

      # TODO Do we need a synthetic message id and a date, if not present?
#      if not head.has_key?('Message-ID')
#        article = "Message-ID: #{@storage.gen_uid}\n" + article
#      end
#      
#      if not head.has_key?('Date')
#        article = "Date: #{Time.now}\n" + article
#      end
    else
      @group = group
      @link = XPath.match(entry, "link").first.attribute("href").to_s
      lp = LinkParser.new(@group, @link)
      @message_id = lp.message_id
      @date = DateTime.strptime(XPath.match(entry, "published").first.text)
      @from = XPath.match(entry, "author/name").first.text
      @subject = XPath.match(entry, "title").first.text.gsub(/^Reply to /, "Re: ")
      @references = lp.thread_id if lp.message_id != lp.thread_id
      @body = XPath.match(entry, "content").first.text
    end
  end
  
  def head
      article = ""
      article << "Message-ID: #{@message_id}" << "\r\n" if !@message_id.nil?
      article << "Date: #{@date}" << "\r\n"
      article << "From: #{@from}" << "\r\n"
      article << "Subject: #{@subject}" << "\r\n"
      article << "References: #{@references}" << "\r\n" if !@references.nil?
      article << "Newsgroups: #{@group.title}" << "\r\n"
      article << "Content-Type: #{@content_type}" << "\r\n" if !@content_type.nil?
      article << "Content-Transfer-Encoding: #{@content_transfer_encoding}" << "\r\n" if !@content_transfer_encoding.nil?
      article
  end
    
  def to_s
      article = head
      article << "\r\n"
      article << @body.to_s
      article
  end

private
  #
  # parse_rfc822 is a modification of parse_rfc822_header from:
  #
  # niouz.rb -- A small, simple NNTP server suitable to set up
  # private newsgroups for an intranet or workgroup.
  #
  # Homepage:: http://pcdavid.net/software/niouz/
  # Author::    Pierre-Charles David (mailto:pcdavid@pcdavid.net)
  # Copyright:: Copyright (c) 2003, 2004 Pierre-Charles David
  # License::   GPL v2 (www.gnu.org/copyleft/gpl.html)
  #
  # Parses the headers of a mail or news article formatted using the
  # RFC822 format. This function does not interpret the headers values,
  # but considers them free-form text. Headers are returned in a Hash
  # mapping header names to values. Ordering is lost. Continuation lines
  # are supported. An exception is raised if a header is given multiple
  # definitions, or if the format does not follow RFC822. 
  # Parsing used to stop when encountering the end of +input+ or an empty line,
  # but instead we read until the body is read as well
  def parse_rfc822(input)
    headers = Hash.new
    previous = nil
    end_of_header = false
    body = ""
    
    input.each_line do |line|
      line = line.chomp
      
      if line.empty?
        end_of_header = true # from now on
      end
      
      if end_of_header
        body << line
      else
        case line
        when /^([^: \t]+):\s+(.*)$/
          raise "Multiple definitions of header '#{$1}'." if headers.has_key?($1)
          headers[previous = $1] = $2
        when /^\s+(.*)$/
          if not previous.nil? and headers.has_key?(previous)
            headers[previous] << "\n" + $1.lstrip
          else
            raise "Invalid header continuation."
          end
        else
          raise "Invalid header format."
        end
      end
    end      
    
    return headers,body
  end
end
