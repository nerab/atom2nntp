require 'rubygems'

#
# TODO We need a sweeper that removes old articles, depending on size and update frequency of the group
#
class NntpSession
  def send_line(data, debug = false)
    log(" > #{data}") if debug
    send_data data.to_s
    send_data "\r\n" if !(data[-1, 1] == "\n")
  end
  
  def receive_data(p_data)
    log("< #{p_data}")
    
    begin
      case p_data.to_s.strip
        when /^GROUP\s+(.+)$/i then send_line(select_group($1), true)
        when /^NEXT$/i         then send_line(move_article_pointer(:next), true)
        when /^LAST$/i         then send_line(move_article_pointer(:previous), true)
        when /^MODE\s+READER/i then send_line('200 reader status acknowledged', true)
        when /^SLAVE$/i        then send_line('202 slave status acknowledged', true)
        when /^IHAVE\s*/i      then send_line('435 article not wanted - do not send it', true)
        when /^DATE$/i         then send_line('111 ' + Time.now.gmtime.strftime("%Y%m%d%H%M%S"), true)
        when /^HELP$/i
          send_line("100 help text follows", true)
          send_line(".")
        
        when /^LIST$/i
          send_line("215 list of newsgroups follows", true)
          Newsgroup.all.each{|group|
            send_line(group.metadata, true)
          }
          send_line(".")
        
        when /^XOVER(\s+\d+)?(-)?(\d+)?$/i
          if @group.nil?
            send_line('412 no news group currently selected', true)
          else
            if not $1    then articles = [ @article.id ]
            elsif not $2 then articles = [ $1.to_i ]
            else
              last = ($3 ? $3.to_i : @group.articles.last(:order => 'id').id)
              articles = @group.articles.all(:conditions => ["id >= :first AND id <= :last", { :first => $1.to_i, :last => last}])
            end
            
            if articles.empty? or articles == [ 0 ]
              send_line('420 no article(s) selected', true)
            else
              send_line('224 Overview information follows', true)
              articles.each do |nb|
                send_line(nb.overview, true)
              end
              send_line('.')
            end
          end

        when /^(ARTICLE|HEAD|BODY|STAT)\s+<(.*)>$/i
          article = Article.find_by_message_id($2)
          if article.nil?
            send_line("430 no such article found", true)
          else
            send_article_part(article, $1)
          end
        
        when /^(ARTICLE|HEAD|BODY|STAT)(\s+\d+)?$/i
          nb = ($2 ? $2.to_i : @article )
          if @group.nil?
            send_line('412 no newsgroup has been selected', true)
          elsif @group.articles.find(nb).nil?
            send_line('423 no such article number in this group', true)
          else
            article = @group.articles.find(nb)
            send_article_part(article, $1)
          end
        
        when /^QUIT$/i
          send_line("205 closing connection - goodbye!", true)
          close_connection
      
      else
        send_line("500 command not supported", true) 
      end
    rescue
      log("- Error handling request: #{$!} (#{caller.join('\n')})")
      send_line("500 Error: #{$!}", true)
    end
  end
  
  def post_init
  end
  
  def connection_completed
  end
  
  def handle_request
    log("- new connection")
    send_line("200 server ready", true)
  end
  
  def parse_pairs(str)
    return [ str[0...2].to_i, str[2...4].to_i, str[4...6].to_i ]
  end
    
  def send_article_part(article, part)
    code, method = case part
      when /ARTICLE/i then [ '220', :content ]
      when /HEAD/i    then [ '221', :head ]
      when /BODY/i    then [ '222', :body ]
      when /STAT/i    then [ '223', nil ]
    end
    send_line("#{code} #{article.id} #{article.message_id} article retrieved", true)
    putlongresp article.send(method) if method
  end
  
  # Sends a multi-line response (for example an article body)
  # to the client.
  def putlongresp(content)
    content.each_line do |line|
      send_line(line.sub(/^\./, '..')) # escape "." as ".."
    end
    send_line('.')
  end
  
  def select_group(name)
    @group = Newsgroup.find_by_title(name)
    if @group.nil?
      return '411 no such news group'
    else
      @article = @group.articles.first(:order => 'id') # @group.first
      return "211 %d %d %d %s" % [@group.size_estimation,
      @article.id,
      @group.articles.last(:order => 'id').id,
      @group.title] # FIXME: sync
    end
  end
  
  def move_article_pointer(direction)
    if @group.nil?
      return '412 no newsgroup selected'
    elsif @article.nil?
      return '420 no current article has been selected'
    else
      # depends on method names
      article = @group.send((direction.to_s + '_article').intern, @article)
      if article
        @article = article
        mid = @article.message_id
        return "223 #{mid} article retrieved: request text separately"
      else
        return "422 no #{direction} article in this newsgroup"
      end
    end
  end
  
  def authenticated?
    !@user.blank? && !@password.blank?
  end
  
  def log(data)
    puts "#{Time.now} - #{self.class.name} #{data.to_s}"
    $stdout.flush    
  end
end
