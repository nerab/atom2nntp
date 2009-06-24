class AddActsAsTree < ActiveRecord::Migration
  def self.up
    change_table(:articles) do |t|
      t.column :parent_id, :integer
    end
    
#    Article.all.each{|a|
#      parent = Article.find_by_message_id(a.references)
#      
#      if !parent.nil?
#        a.parent = parent
#        a.save!
#      end
#    }
    
  end

  def self.down
    change_table(:articles) do |t|
      t.remove_column :parent_id
    end
  end
end
