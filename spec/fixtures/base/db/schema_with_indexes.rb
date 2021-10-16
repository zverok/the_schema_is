ActiveRecord::Schema.define(version: 20160712061614) do

  create_table "articles", force: :cascade do |t|
    t.string   "title"
    t.string   "slug",            limit: 200, index: {name: "index_articles_on_slug", :unique=>true}
    t.text     "body"
    t.string   "description"
    t.integer  "favorites_count"
    t.integer  "user_id",         foreign_key: {references: "users", name: "fk_articles_user_id", on_update: :restrict, on_delete: :cascade}
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
  end
end
