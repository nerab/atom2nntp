# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20090626144009) do

  create_table "articles", :force => true do |t|
    t.string   "link"
    t.string   "message_id"
    t.string   "from"
    t.string   "subject"
    t.string   "references"
    t.text     "body"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "newsgroup_id"
    t.datetime "date"
    t.integer  "parent_id"
    t.string   "boundary"
    t.string   "plaintext_body"
  end

  create_table "bdrb_job_queues", :force => true do |t|
    t.text     "args"
    t.string   "worker_name"
    t.string   "worker_method"
    t.string   "job_key"
    t.integer  "taken"
    t.integer  "finished"
    t.integer  "timeout"
    t.integer  "priority"
    t.datetime "submitted_at"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "archived_at"
    t.string   "tag"
    t.string   "submitter_info"
    t.string   "runner_info"
    t.string   "worker_key"
    t.datetime "scheduled_at"
  end

  create_table "newsgroups", :force => true do |t|
    t.string   "title"
    t.string   "alternate_link"
    t.string   "icon_url"
    t.text     "subtitle"
    t.date     "updated"
    t.string   "generator"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "feed_url"
  end

end
