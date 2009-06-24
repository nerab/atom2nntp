class FetchArticlesWorker < BackgrounDRb::MetaWorker
  set_worker_name :fetch_articles_worker
  def create(args = nil)
    add_periodic_timer(60){fetch_articles}
  end
  
  def fetch_articles
    Newsgroup.all.each{|newsgroup|
      begin
        ArticleFetcher.articles(newsgroup)
      rescue
        logger.error "#{Time.now} - Error fetching feed: #{$!} (#{caller.collect})"
      end
    }
  end
end
