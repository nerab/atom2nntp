class CreateNewsgroups < ActiveRecord::Migration
  def self.up
    create_table :newsgroups do |t|
      t.string :title
      t.string :alternate_link
      t.string :icon_url
      t.text :subtitle
      t.date :updated
      t.string :generator

      t.timestamps
    end
  end

  def self.down
    drop_table :newsgroups
  end
end
