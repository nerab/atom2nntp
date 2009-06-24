class LinkParser
    def initialize(group, href)
        @group   = group        
        parts = href.match('http://(www.)?flickr.com/groups/(.*)/discuss/(\d*)/(\d*)')
        @group_id   = parts[2]
        @thread_id  = parts[3]
        @message_id = parts[4]
    end

    def message_id
        if @message_id.empty?
            thread_id
        else
            "#{@message_id}.#{@thread_id}@#{@group.title}"
        end
    end

    def thread_id
        "#{@thread_id}@#{@group.title}"
    end
    
    def thread_url
        "http://www.flickr.com/groups/#{@group_id}/discuss/#{@thread_id}"
    end
end
