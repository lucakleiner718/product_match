# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20150911183144) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "product_selects", force: :cascade do |t|
    t.integer  "product_id"
    t.integer  "selected_id"
    t.integer  "selected_percentage"
    t.datetime "created_at",          null: false
    t.datetime "updated_at",          null: false
    t.string   "decision"
  end

  create_table "product_suggestions", force: :cascade do |t|
    t.integer  "product_id"
    t.integer  "suggested_id"
    t.integer  "percentage"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
  end

  add_index "product_suggestions", ["product_id", "suggested_id"], name: "index_product_suggestions_on_product_id_and_suggested_id", unique: true, using: :btree
  add_index "product_suggestions", ["product_id"], name: "index_product_suggestions_on_product_id", using: :btree

  create_table "products", force: :cascade do |t|
    t.string   "brand"
    t.string   "source"
    t.string   "source_id"
    t.string   "kind"
    t.string   "retailer"
    t.string   "title"
    t.string   "category"
    t.string   "url"
    t.string   "image"
    t.text     "additional_images", default: [],              array: true
    t.string   "price"
    t.string   "price_sale"
    t.string   "color"
    t.string   "size"
    t.string   "material"
    t.string   "gender"
    t.string   "upc"
    t.string   "mpn"
    t.string   "ean"
    t.string   "sku"
    t.string   "style_code"
    t.string   "item_group_id"
    t.string   "google_category"
    t.text     "description"
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
  end

  add_index "products", ["brand"], name: "index_products_on_brand", using: :btree
  add_index "products", ["color"], name: "index_products_on_color", using: :btree
  add_index "products", ["ean"], name: "index_products_on_ean", using: :btree
  add_index "products", ["mpn"], name: "index_products_on_mpn", using: :btree
  add_index "products", ["size"], name: "index_products_on_size", using: :btree
  add_index "products", ["source", "source_id"], name: "index_products_on_source_and_source_id", using: :btree
  add_index "products", ["style_code"], name: "index_products_on_style_code", using: :btree
  add_index "products", ["title"], name: "index_products_on_title", using: :btree
  add_index "products", ["upc"], name: "index_products_on_upc", using: :btree

end
