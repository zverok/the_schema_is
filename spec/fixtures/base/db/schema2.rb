ActiveRecord::Schema.define(version: 20160712061614) do

  create_table "dogs", force: :cascade do |t|
    t.string "name"
  end
end
