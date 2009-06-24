class ChangeArticleDateToDateTime < ActiveRecord::Migration
  def self.up
    change_table(:articles) do |t|
      t.remove :date
      t.column :date, :datetime
    end
  end

  def self.down
    change_table(:articles) do |t|
      t.remove :date, :datetime
      t.column :date, :date
    end
  end
end
