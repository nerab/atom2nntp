class UpdateArticlesWorker < BackgrounDRb::MetaWorker
  set_worker_name :update_articles_worker
  def create(args = nil)
    add_periodic_timer(60){update_articles}
  end
  
  def update_articles
    Newsgroup.all.each{|newsgroup|
      begin
        ArticleFetcher.update(newsgroup)
      rescue
        logger.error "#{Time.now} - Error updating group: #{$!} (#{caller.collect})"
      end
    }
  end
end
