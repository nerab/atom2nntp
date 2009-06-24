class AddNewsgroupFeedUtl < ActiveRecord::Migration
  def self.up
	  change_table(:newsgroups) do |t|
      t.column :feed_url, :string
	  end
    change_table(:articles) do |t|
    	t.references :newsgroup
    end
  end

  def self.down
	  change_table(:newsgroups) do |t|
	    t.remove :feed_url, :string
    end
    change_table(:articles) do |t|
    	t.remove_references :newsgroup
    end
  end
end
