require 'open-uri'
require 'rexml/document'
require 'htmlentities'

include REXML

class HTML2Text
  class << self
    CODER = HTMLEntities.new

    def text(txt)
      body = []
      
      doc = Document.new(txt)
      
      doc.root.children.each{|e|
        body << translate(e)
      }
      
      body.join
    end
    
    #
    # Translates HTML elements into their text equivalent
    #
    def translate(elem)
      if !elem.respond_to?(:children) # no children
        CODER.decode(elem.to_s)
      else
        child_text = elem.children.collect{|child| translate(child)}.join
        case elem.name
          when "br" # cannot have children
            "" # "\n"
          when "i"
            "/#{child_text}/"
          when "b"
            "*#{child_text}*"
          when "blockquote"
            "\n\t#{child_text}"
          when "a"
            "[#{translate(elem.text)}|#{elem.attribute('href')}]"
          when "img"
            "image '#{elem.attribute('alt')}' from #{elem.attribute('src')}"
          else
            raise "Unexpected element name #{elem.name}"
        end
      end
    end
  end
end

