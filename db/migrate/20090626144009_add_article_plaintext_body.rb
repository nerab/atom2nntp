class AddArticlePlaintextBody < ActiveRecord::Migration
  def self.up
    change_table(:articles) do |t|
      t.column :plaintext_body, :string
    end
    
    Article.all.each{|a|
      a.plaintext_body = HTML2Text.text(a.body)
      a.save!
    }
  end

  def self.down
    change_table(:articles) do |t|
	    t.remove :plaintext_body, :string
    end
  end
end
