require "nntp_session"

class NntpWorker < BackgrounDRb::MetaWorker
  set_worker_name :nntp_worker
  
  def create(args = nil)
    start_server("0.0.0.0", 8119, NntpSession) do |client_connection|
      begin
        client_connection.handle_request
      rescue
        puts "#{Time.now} - #{self.class.name} - Error handling request: #{$!}"
      end    
    end
  end
end
