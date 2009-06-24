class Newsgroup < ActiveRecord::Base
  has_many :articles, :dependent => :destroy
  validates_uniqueness_of(:feed_url)

  def self.canonical_group_name(name)
    name.gsub(/ /, "_").gsub(/\./, "_")
  end  

  # Returns a string describing the state of this newsgroup,
  # as expected by the +LIST+ and +NEWSGROUPS+ commands.
  def metadata
    first = articles.first(:order => 'id')
    last = articles.last(:order => 'id')
    return "#{title} #{last ? last.id : 0} #{first ? first.id : 0} y"
  end
  
  # Returns an estimation of the number of articles in this newsgroup.
  def size_estimation
    return articles.count
  end

  # Returns the smallest valid article number strictly superior to
  # +from+, or nil if there is none.
  def next_article(from)
    Article.first :conditions =>  ["id > ?", from]
  end

  # Returns the greatest valid article number strictly inferior to
  # +from+, or nil if there is none.
  def previous_article(from)
    Article.first :conditions =>  ["id < ?", from]
  end
  
  def threads
    articles.find(:all, :conditions => "parent_id IS NULL").sort{|a,b| a.date <=> b.date}
  end
end
