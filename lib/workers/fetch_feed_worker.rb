class FetchFeedWorker < BackgrounDRb::MetaWorker
  set_worker_name :fetch_feed_worker
  def create(args = nil)
    # this method is called, when worker is loaded for the first time
  end
  
  def fetch_feed(url)
    NewsgroupFetcher.create_newsgroup(url)
  end
end

