#!/usr/bin/env ruby
# niouz.rb -- A small, simple NNTP server suitable to set up
# private newsgroups for an intranet or workgroup.
#
# Homepage:: http://pcdavid.net/software/niouz/
# Author::    Pierre-Charles David (mailto:pcdavid@pcdavid.net)
# Copyright:: Copyright (c) 2003, 2004 Pierre-Charles David
# License::   GPL v2 (www.gnu.org/copyleft/gpl.html)

require 'socket'
require 'thread'
require 'time'
require 'md5'

## <StUhl>
require 'rfc822_article'
require 'feed_client'
## </StUhl>

PROG_NAME = 'niouz'
PROG_VERSION  = '0.5-uh'

# Format of the overview "database", as an ordered list of header
# names. See RCF 2980, Sections 2.1.7 ("LIST OVERVIEW.FMT") & 2.8
# ("XOVER").
OVERVIEW_FMT = [
  'Subject', 'From', 'Date', 'Message-ID', 'References', 'Bytes', 'Lines'
]

# Parses the headers of a mail or news article formatted using the
# RFC822 format. This function does not interpret the headers values,
# but considers them free-form text. Headers are returned in a Hash
# mapping header names to values. Ordering is lost. Continuation lines
# are supported. An exception is raised if a header is given multiple
# definitions, or if the format does not follow RFC822. Parsing stops
# when encountering the end of +input+ or an empty line.
def parse_rfc822_header(input)
  headers = Hash.new
  previous = nil
  input.each_line do |line|
    line = line.chomp
    break if line.empty?     # Stop at first blank line
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
  return headers.empty? ? nil : headers
end

# Utility to parse dates
def parse_date(aString)
  return Time.rfc822(aString) rescue Time.parse(aString)
end

# Represents a news article stored as a simple text file in RFC822
# format. Only the minimum information is kept in memory by instances
# of this class:
# * the message-id (+Message-ID+ header)
# * the names of the newsgroups it is posted to (+Newsgroups+ header)
# * the date it was posted (+Date+ header)
# * overview data, generated on creation (see OVERVIEW_FMT)
#
# The rest (full header and body) are re-read from the file
# each time it is requested.
#
# None of the methods in this class ever modify the content
# of the file storing the article or the state of the instances
# once created. Thread-safe.
class Article
  # Creates a new Article from the content of file +fname+.
  def initialize(fname)
    @file = fname
    headers = File.open(fname) { |file| parse_rfc822_header(file) }
    @mid = headers['Message-ID']
    @newsgroups = headers['Newsgroups'].split(/\s*,\s*/)
    @date = parse_date(headers['Date'])
    # +Bytes+ and +Lines+ headers are required by the default
    # overview format, but they are not generated by all clients.
    # Only used for overview generation.
    headers['Bytes'] ||= File.size(fname).to_s
    headers['Lines'] ||= File.readlines(fname).length.to_s
    @overview = OVERVIEW_FMT.collect do |h|
      headers[h] ? headers[h].gsub(/(\r\n|\n\r|\n|\t)/, ' ') : nil
    end.join("\t")
  end

  # The message identifer.
  attr_reader :mid

  # The list of newsgroups (names) this article is in.
  attr_reader :newsgroups

  # Overview of this article (see OVERVIEW_FMT).
  attr_reader :overview

  # Tests whether this Article already existed at the given time.
  def existed_at?(aTime)
    return @date >= aTime
  end

  # Returns the head of the article, i.e. the content of the
  # associated file up to the first empty line.
  def head
    header = ''
    File.open(@file).each_line do |line|
      break if line.chomp.empty?
      header << line
    end
    return header
  end

  # Returns the body of the article, i.e. the content of the
  # associated file starting from the first empty line.
  def body
    lines = ''
    in_head = true
    File.open(@file).each_line do |line|
      in_head = false if in_head and line.chomp.empty?
      lines << line unless in_head
    end
    return lines
  end

  # Returns the full content of the article, head and body. This is
  # simply the verbatim content of the associated file.
  def content
    return IO.read(@file)
  end

  def matches_groups?(groups_specs) # TODO
    # See description of NEWNEWS command in RFC 977.
    return true
  end
end

# Represents a newsgroup, i.e. a numbered sequence of Articles,
# identified by a name. Note that article are numbered starting from
# 1.
#
# This class does not read or write anything from the disk.
# Thread-safe (I think).
class Newsgroup
  # Creates a new, empty Newsgroup.
  # [+name+] the name of the Newsgroup (e.g. "comp.lang.ruby").
  # [+created+] the Time the newsgroup was created (posted).
  # [+description+] a short description of the newsgroup subject.
  def initialize(name, creation, description)
    @name, @creation, @description = name, creation, description
    @articles = Array.new
    @first, @last = 0, 0
    @lock = Mutex.new
  end

  attr_reader :name, :description

  def sync
    return @lock.synchronize { yield }
  end

  private :sync

  # Returns the index of the first article (lowest numbered) in this
  # group. Note that articles are indexed starting from 1, and a
  # return value of 0 means the newsgroup is empty.
  def first
    return sync { @first }
  end

  # Returns the index of the last article (highest numbered) in this
  # group. Note that articles are indexed starting from 1, and a
  # return value of 0 means the newsgroup is empty.
  def last
    return sync { @last }
  end

  # Returns a string describing the state of this newsgroup,
  # as expected by the +LIST+ and +NEWSGROUPS+ commands.
  def metadata
    return sync { "#@name #@last #@first y" }
  end

  # Tests whether this Newsgroup already existed at the given time.
  def existed_at?(aTime)
    return @creation >= aTime
  end

  # Returns an Article by number.
  def [](nb)
    return sync { @articles[nb - 1] }
  end

  # Adds a new Article to this newsgroup.
  def add(article)
    sync {
      @articles << article
      @first = 1
      @last += 1
    }
  end

  # Tests whether this newsgroup has an article numbered +nb+.
  def has_article?(nb)
    return sync { not @articles[nb - 1].nil? }
  end

  # Returns an estimation of the number of articles in this newsgroup.
  def size_estimation
    return sync { @last - @first + 1 }
  end

  # Returns the smallest valid article number strictly superior to
  # +from+, or nil if there is none.
  def next_article(from)
    sync {
      current = from + 1
      while current <= @last
        break if @articles[current - 1]
        current += 1
      end
      (current > @last) ? nil : current
    }
  end

  # Returns the greatest valid article number strictly inferior to
  # +from+, or nil if there is none.
  def previous_article(from)
    sync {
      current = from - 1
      while current >= @first
        break if @articles[current - 1]
        current -= 1
      end
      (current < @first) ? nil : current
    }
  end

  def matches_distribs?(distribs) # TODO
    if distribs.nil? or distribs.empty?
      return true
    else
      distribs.each do |dist|
        return true if name[0..dist.length] == dist
      end
      return false
    end
  end
end

# This class manages the "database" of groups and articles.
class Storage
  def initialize(dir)
    File.open(File.join(dir, 'newsgroups')) do |file|
      @groups = load_groups(file)
    end
    @pool = File.join(dir, 'articles')
    @last_file_id = 0
    @lock = Mutex.new
    @articles = Hash.new
    Dir.foreach(@pool) do |fname|
      next if fname[0] == ?.
      @last_file_id = [ @last_file_id, fname.to_i ].max
      register_article(fname)
    end
  end

  # Parses the newsgroups description file.
  def load_groups(input)
    groups = Hash.new
    while g = parse_rfc822_header(input)
      date = parse_date(g['Date-Created'])
      groups[g['Name']] = Newsgroup.new(g['Name'], date, g['Description'])
    end
    return groups
  end

  def register_article(fname)
    art = Article.new(File.join(@pool, fname))
    @articles[art.mid] = art

    art.newsgroups.each do |gname|
      @groups[gname].add(art) if has_group?(gname)
    end
  end

  private :register_article, :load_groups

  def group(name)
    return @groups[name]
  end

  def has_group?(name)
    return @groups.has_key?(name)
  end

  def each_group
    @groups.each_value {|grp| yield(grp) }
  end

  def article(mid)
    return @lock.synchronize { @articles[mid] }
  end

  def groups_of(article)
    return article.groups.collect { |name| @groups[name] }
  end

  def each_article
    articles = @lock.synchronize { @articles.dup }
    articles.each { |art| yield(art) }
  end

  def create_article(content)
    begin
      @lock.synchronize {
        @last_file_id += 1;
        fname = "%06d" % [ @last_file_id ]
        File.open(File.join(@pool, fname), "w") { |f| f.write(content) }
        register_article(fname)
      }
      return true
    rescue
      return false
    end
  end

  def gen_uid
    return "<" + MD5.hexdigest(Time.now.to_s) + "@" + Socket.gethostname + ">"
  end
end

############################################################

class NNTPSession
  def initialize(socket, storage)
    @socket, @storage = socket, storage
    @group = nil
    @article = nil
  end

  def close
    @socket.close
  end

  # Sends a single-line response to the client
  def putline(line)
    @socket.puts(line.chomp)
  end

  # Sends a multi-line response (for example an article body)
  # to the client.
  def putlongresp(content)
    content.each_line do |line|
      putline line.sub(/^\./, '..')
    end
    putline '.'
  end

  # Reads a single line from the client and returns it.
  def getline
    return @socket.gets
  end

  # Reads a multi-line message from a client (normally an
  # article being posted).
  def getarticle
    lines = []
    while true
      line, char = '', nil
      while char != "\n"
        line << (char = @socket.recv(1))
      end
      line.chomp!
      break if line == '.'
      line = line[1..-1] if line.to_s[0...2] == '..'
      lines << line
    end
    return lines.join("\n")
  end

  def select_group(name)
    if @storage.has_group?(name)
      @group = @storage.group(name)
      @article = @group.first
      return "211 %d %d %d %s" % [@group.size_estimation,
                                  @group.first,
                                  @group.last,
                                  @group.name] # FIXME: sync
    else
      return '411 no such news group'
    end
  end

  def move_article_pointer(direction)
    if @group.nil?
      return '412 no newsgroup selected'
    elsif @article.nil?
      return '420 no current article has been selected'
    else
      # HACK: depends on method names
      article = @group.send((direction.to_s + '_article').intern, @article)
      if article
        @article = article
        mid = @group[@article].mid
        return "223 #@article #{mid} article retrieved: request text separately"
      else
        return "422 no #{direction} article in this newsgroup"
      end
    end
  end

  def parse_pairs(str)
    return [ str[0...2].to_i, str[2...4].to_i, str[4...6].to_i ]
  end

  def read_time(date, time, gmt)
    year, month, day = parse_pairs(date)
    year += ( year > 50 ) ? 1900 : 2000
    hour, min, sec = parse_pairs(time)
    if gmt =~ /GMT/i
      return Time.gm(year, month, day, hour, min, sec)
    else
      return Time.local(year, month, day, hour, min, sec)
    end
  end

  def send_article_part(article, nb, part)
    code, method = case part
                   when /ARTICLE/i then [ '220', :content ]
                   when /HEAD/i    then [ '221', :head ]
                   when /BODY/i    then [ '222', :body ]
                   when /STAT/i    then [ '223', nil ]
                   end
    putline "#{code} #{nb} #{article.mid} article retrieved"
    putlongresp article.send(method) if method
  end

  def overview(n, article)
    return n.to_s + "\t" + article.overview
  end

  def serve
    putline "200 server ready (#{PROG_NAME} -- #{PROG_VERSION})"
    while (request = getline)
      puts "#{Time.now} - #{self.class.name} - #{request.strip}"
      case request.strip
      when /^GROUP\s+(.+)$/i then putline select_group($1)
      when /^NEXT$/i         then putline move_article_pointer(:next)
      when /^LAST$/i         then putline move_article_pointer(:previous)
      when /^MODE\s+READER/i then putline '200 reader status acknowledged'
      when /^SLAVE$/i        then putline '202 slave status acknowledged'
      when /^IHAVE\s*/i      then putline '435 article not wanted - do not send it'
      when /^DATE$/i
        putline '111 ' + Time.now.gmtime.strftime("%Y%m%d%H%M%S")
      when /^HELP$/i
        putline "100 help text follows"
        putline "."

      when /^LIST$/i
        putline "215 list of newsgroups follows"
        @storage.each_group { |group| putline group.metadata }
        putline "."

      when /^LIST\s+OVERVIEW\.FMT$/i
        if OVERVIEW_FMT
          putline '215 order of fields in overview database'
          OVERVIEW_FMT.each { |header| putline header + ':' }
          putline "."
        else
          putline '503 program error, function not performed'
        end

      when /^XOVER(\s+\d+)?(-)?(\d+)?$/i
        if @group.nil?
          putline '412 no news group currently selected'
        else
          if not $1    then articles = [ @article ]
          elsif not $2 then articles = [ $1.to_i ]
          else
            last = ($3 ? $3.to_i : @group.last)
            articles = ($1.to_i .. last).select { |n| @group.has_article?(n) }
          end
          if articles.compact.empty? or articles == [ 0 ]
            putline '420 no article(s) selected'
          else
            putline '224 Overview information follows'
            articles.each do |nb|
              putline(nb.to_s + "\t" + @group[nb].overview)
            end
            putline '.'
          end
        end

      when /^NEWGROUPS\s+(\d{6})\s+(\d{6})(\s+GMT)?(\s+<.+>)?$/i
        time = read_time($1, $2, $3)
        distribs = ( $4 ? $4.strip.delete('<> ').split(/,/) : nil )
        putline "231 list of new newsgroups follows"
        @storage.each_group do |group|
          if group.existed_at?(time) and group.matches_distribs?(distribs)
            putline group.metadata
          end
        end
        putline "."

      when /^NEWNEWS\s+(.*)\s+(\d{6})\s+(\d{6})(\s+GMT)?\s+(<.+>)?$/i
        groups = $1.split(/\s*,\s*/)
        time = read_time($2, $3, $4)
        distribs = ( $5 ? $5.strip.delete('<> ').split(/,/) : nil )
        putline "230 list of new articles by message-id follows"
        @storage.each_article do |article|
          if article.existed_at?(time) and article.matches_groups?(groups) and
              @storage.groups_of(article).any? { |g| g.matches_distribs?(distribs) }
            putline article.mid.sub(/^\./, '..')
          end
        end
        putline "."

      when /^(ARTICLE|HEAD|BODY|STAT)\s+<(.*)>$/i
        article = @storage.article($2)
        if article.nil?
          putline "430 no such article found"
        else
          send_article_part(article, nil, $1)
        end

      when /^(ARTICLE|HEAD|BODY|STAT)(\s+\d+)?$/i
        nb = ($2 ? $2.to_i : @article )
        if @group.nil?
          putline '412 no newsgroup has been selected'
        elsif not @group.has_article?(nb)
          putline '423 no such article number in this group'
        else
          article = @group[@article = nb]
          send_article_part(article, @article, $1)
        end

      when /^POST$/i         # Article posting
        putline '340 Send article to be posted'
        article = getarticle
        head = parse_rfc822_header(article)
        if not head.has_key?('Message-ID')
          article = "Message-ID: #{@storage.gen_uid}\n" + article
        end
        if not head.has_key?('Date')
          article = "Date: #{Time.now}\n" + article
        end
        if @storage.create_article(article)
          putline '240 Article received ok'
        else
          putline '441 Posting failed'
        end

      when /^QUIT$/i         # Session end
        putline "205 closing connection - goodbye!"
        close
        return

      else
        putline "500 command not supported"
      end
    end
  end
end

if __FILE__ == $0
  if ARGV.length != 1
    puts "Usage: #{$0} storage_dir"
    exit 1
  else
    if not (File.directory?(ARGV[0]) && File.executable?(ARGV[0]))
      puts "Directory #{ARGV[0]} must exist and be executable/traversable."
      exit 2
    end
    require 'webrick/server'

## <StUhl>
    # Deamonization (thanks to Reimer Behrends, see [ruby-talk:87467])
    # exit if fork
    # Process.setsid
    # exit if fork
    # Dir.chdir ARGV[0]
    # File.umask 0000
    # STDIN.reopen "/dev/null"
    # STDOUT.reopen "/dev/null", "a"
    # STDERR.reopen STDOUT
## </StUhl>

    store = Storage.new(ARGV[0])

## <StUhl>
    # shutdown = false
    Thread.new{
        loop do
            puts "ping ..."
            begin
                url = "http://api.flickr.com/services/feeds/groups_discuss.gne?id=71917374@N00&lang=en-us&format=atom"
                FeedClient.new(url).articles.each{|article|
                    if store.article(article.mid).nil?
                        puts "Storing new article #{article.mid}"
                        store.create_article(article.to_s)
                    else
                        # puts "Article #{article.mid} already exists"
                    end
                }
            rescue
                puts "Error: #{$!}"
            end
            break if server.status == :Stop
            sleep 30
        end
    }
## </StUhl>

    server = WEBrick::GenericServer.new(:Port => 119)
    trap("INT") { server.shutdown }# ; shutdown = true
    File.open("pid", "w") { |f| f.puts($$); }
    begin
      server.start { |sock| NNTPSession.new(sock, store).serve }
    ensure
      File.delete("pid")
    end
  end
end
