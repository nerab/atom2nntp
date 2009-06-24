require 'rubygems'
require 'mechanize'

#
# Run this with SSL from home directory: sudo stunnel -d 563 -r 8119 -p ./news.familie-uhlig.net.pem
#
# TODO We need a sweeper that removes old articles, depending on size and update frequency of the group
# TODO Implement cancel messages
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
        
        when /^POST$/i         # Article posting
          if !authenticated?
            send_line("480 Permission denied", true) # require username and password
          else
            send_line('340 Send article to be posted', true)
            @posting_mode = true
          end
          
        when /^AUTHINFO\s+USER\s+(.+)$/i
          log("- Received user name #{$1}")
          
          if !@password.nil?
            send_line("482 Authentication commands issued out of sequence", true)
          else
            if $1.blank?
              log("- Rejecting empty user name #{$1}")
              send_line("481 Authentication failed/rejected", true)
            else
              @user = $1
              send_line("381 Password required", true)
            end
          end
          
        when /^AUTHINFO\s+PASS\s+(.+)$/i
          log("- Received password #{$1} for user name #{@user}")
          
          if @user.nil?
            send_line("482 Authentication commands issued out of sequence", true)
          else
            if $1.blank?
              log("- Rejecting empty password for user name #{@user}")
              send_line("481 Authentication failed/rejected", true)
            else
              @password = $1
              send_line("281 Authentication accepted", true)
            end
          end

        when /^QUIT$/i
          send_line("205 closing connection - goodbye!", true)
          close_connection
      
      else
        if @posting_mode.nil? 
          send_line("500 command not supported", true) # not in posting mode, command not understood
        else
          begin
            article = RFC822Article.new(p_data.to_s)
            log("- Now posting article: #{article.from}: #{article.subject} to flickr (credentials: #{@user}:#{@password})")
            
            # Post article to flickr. If successful, return OK, otherwise raise exception
            # BUG The references header may contain more than a single message id, separated by spaces
            if (!article.references.blank?)
              post_reply(Article.find_by_message_id(article.references).link, article.body)
            else
              # TODO Add post_url to class Newsgroup
              post_new(article.group.post_url, article.body)
            end
          
            log("- Success")
            send_line '240 Article received ok'
          rescue
            send_line '441 Posting failed'
            log("- Error handling request: #{$!} (#{caller.join('\n')})")
          ensure
            @posting_mode = false # next data received will be treated as a regular NNTP command
          end          
        end
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
  
  def post_reply(p_url, message)
    url = URI.parse(p_url)
    
    res = Net::HTTP.start(url.host, url.port) {|http|
        req = Net::HTTP::Post.new(url.path)
        
        # TODO Add mapping from authenticated user to the flickr cookie
        req.add_field 'Cookie', 'cookie_session=826357%3Abffa143d1bd9a6fc331ae661597293dd'
        req.add_field 'Referer', url.to_s
        req.add_field 'Content-Type', 'application/x-www-form-urlencoded'
        req.set_form_data({'message'=> message, 'done'=>'1'})
        http.request(req)
    }
    
    res.code == 302
  end
  
  # Posting a new topic:
  # 1. Retrieve http://www.flickr.com/groups_newtopic.gne?id=13858278@N00
  # 2. Extract magic cookie value
  # 3. Post to http://www.flickr.com/groups_newtopic.gne with
  #   name="magic_cookie" value="e16cf3ed0c05d2e497ab7d7335831a6b"
  #   name="id" value="13858278@N00"
  #   name="done" value="1"
  #   name="subject" value="..."
  #   name="message" value="..."
  def post_new(p_url, message)
    
  end
  
  def flickr_login
    agent = WWW::Mechanize.new
    page  = agent.get('http://www.flickr.com/signin/')
    page.forms.each{|form|
      if form.name == 'login_form'
        form.login = @user # "SteffenUhlig2004"
        form.passwd = @password # "PhSl(13)"
        page  = agent.submit(form)
    
        # execute manual redirect
        page = page.links.first.click
    
        # Check for being logged on
        
      end
    }        
  end
end
