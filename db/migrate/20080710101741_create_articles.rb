class CreateArticles < ActiveRecord::Migration
  def self.up
    create_table :articles do |t|
      t.string :link
      t.string :message_id
      t.date :date
      t.string :from
      t.string :subject
      t.string :references
      t.text :body

      t.timestamps
    end
  end

  def self.down
    drop_table :articles
  end
end
