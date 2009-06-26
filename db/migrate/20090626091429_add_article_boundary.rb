class AddArticleBoundary < ActiveRecord::Migration
  def self.up
    change_table(:articles) do |t|
      t.column :boundary, :string
    end
    
    Article.all.each{|a|
      a.boundary = "Multipart_#{DateTime.now.to_s(:number)}_#{a.id}"
      a.save!
    }
  end

  def self.down
    change_table(:articles) do |t|
	    t.remove :boundary, :string
    end
  end
end
