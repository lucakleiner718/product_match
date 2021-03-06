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

ActiveRecord::Schema.define(version: 20160409161247) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_admin_comments", force: :cascade do |t|
    t.string   "namespace"
    t.text     "body"
    t.string   "resource_id",   null: false
    t.string   "resource_type", null: false
    t.integer  "author_id"
    t.string   "author_type"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "active_admin_comments", ["author_type", "author_id"], name: "index_active_admin_comments_on_author_type_and_author_id", using: :btree
  add_index "active_admin_comments", ["namespace"], name: "index_active_admin_comments_on_namespace", using: :btree
  add_index "active_admin_comments", ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource_type_and_resource_id", using: :btree

  create_table "active_products", force: :cascade do |t|
    t.string   "title"
    t.integer  "brand_id"
    t.string   "price"
    t.string   "category"
    t.string   "source"
    t.string   "style_code"
    t.string   "image"
    t.text     "additional_images", default: [], array: true
    t.string   "gender"
    t.string   "material"
    t.string   "google_category"
    t.string   "url"
    t.datetime "shopbop_added_at"
    t.integer  "retailers_count"
  end

  create_table "brand_duplicates", force: :cascade do |t|
    t.integer  "target_brand_id"
    t.integer  "duplicate_brand_id"
    t.boolean  "processed"
    t.datetime "processed_at"
    t.datetime "created_at",         null: false
    t.datetime "updated_at",         null: false
  end

  create_table "brand_stats", force: :cascade do |t|
    t.integer  "brand_id"
    t.integer  "shopbop_size"
    t.integer  "shopbop_noupc_size"
    t.integer  "shopbop_matched_size"
    t.string   "amounts_content"
    t.integer  "amounts_values"
    t.integer  "suggestions"
    t.datetime "updated_at",           null: false
    t.integer  "suggestions_green"
    t.integer  "suggestions_yellow"
    t.integer  "shopbop_nothing_size"
    t.integer  "new_match_today"
    t.integer  "new_match_week"
    t.integer  "not_matched"
  end

  add_index "brand_stats", ["amounts_values"], name: "index_brand_stats_on_amounts_values", using: :btree
  add_index "brand_stats", ["brand_id"], name: "index_brand_stats_on_brand_id", unique: true, using: :btree
  add_index "brand_stats", ["new_match_today"], name: "index_brand_stats_on_new_match_today", using: :btree
  add_index "brand_stats", ["new_match_week"], name: "index_brand_stats_on_new_match_week", using: :btree
  add_index "brand_stats", ["not_matched"], name: "index_brand_stats_on_not_matched", using: :btree
  add_index "brand_stats", ["shopbop_matched_size"], name: "index_brand_stats_on_shopbop_matched_size", using: :btree
  add_index "brand_stats", ["shopbop_nothing_size"], name: "index_brand_stats_on_shopbop_nothing_size", using: :btree
  add_index "brand_stats", ["shopbop_noupc_size"], name: "index_brand_stats_on_shopbop_noupc_size", using: :btree
  add_index "brand_stats", ["shopbop_size"], name: "index_brand_stats_on_shopbop_size", using: :btree
  add_index "brand_stats", ["suggestions"], name: "index_brand_stats_on_suggestions", using: :btree
  add_index "brand_stats", ["suggestions_green"], name: "index_brand_stats_on_suggestions_green", using: :btree
  add_index "brand_stats", ["suggestions_yellow"], name: "index_brand_stats_on_suggestions_yellow", using: :btree
  add_index "brand_stats", ["updated_at"], name: "index_brand_stats_on_updated_at", using: :btree

  create_table "brands", force: :cascade do |t|
    t.string   "name"
    t.text     "synonyms",   default: [],                 array: true
    t.boolean  "in_use",     default: false
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
    t.boolean  "disabled",   default: false
  end

  add_index "brands", ["name"], name: "index_brands_on_name", unique: true, using: :btree
  add_index "brands", ["synonyms"], name: "index_brands_on_synonyms", using: :btree

  create_table "product_selects", force: :cascade do |t|
    t.integer  "product_id"
    t.integer  "selected_id"
    t.integer  "selected_percentage"
    t.datetime "created_at",          null: false
    t.datetime "updated_at",          null: false
    t.string   "decision"
    t.integer  "user_id"
  end

  add_index "product_selects", ["user_id"], name: "index_product_selects_on_user_id", using: :btree

  create_table "product_sources", force: :cascade do |t|
    t.string   "name"
    t.string   "source_name"
    t.string   "source_id"
    t.datetime "collected_at"
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
    t.integer  "brand_id"
    t.json     "data"
    t.integer  "period",                 default: 0, null: false
    t.string   "collect_status_code"
    t.string   "collect_status_message"
  end

  add_index "product_sources", ["brand_id"], name: "index_product_sources_on_brand_id", using: :btree
  add_index "product_sources", ["collect_status_code"], name: "index_product_sources_on_collect_status_code", using: :btree
  add_index "product_sources", ["name"], name: "index_product_sources_on_name", using: :btree
  add_index "product_sources", ["source_name", "source_id"], name: "index_product_sources_on_source_name_and_source_id", unique: true, using: :btree

  create_table "product_suggestions", force: :cascade do |t|
    t.integer  "product_id"
    t.integer  "suggested_id"
    t.integer  "percentage"
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.string   "price"
    t.string   "price_sale"
    t.text     "upc_patterns", default: [],              array: true
  end

  add_index "product_suggestions", ["percentage"], name: "index_product_suggestions_on_percentage", using: :btree
  add_index "product_suggestions", ["product_id", "suggested_id"], name: "index_product_suggestions_on_product_id_and_suggested_id", unique: true, using: :btree
  add_index "product_suggestions", ["product_id"], name: "index_product_suggestions_on_product_id", using: :btree
  add_index "product_suggestions", ["suggested_id"], name: "index_product_suggestions_on_suggested_id", using: :btree

  create_table "product_upcs", force: :cascade do |t|
    t.integer  "product_id"
    t.string   "upc"
    t.datetime "created_at",         null: false
    t.text     "selected_ids",                    array: true
    t.text     "product_select_ids",              array: true
  end

  add_index "product_upcs", ["created_at"], name: "index_product_upcs_on_created_at", using: :btree
  add_index "product_upcs", ["product_id"], name: "index_product_upcs_on_product_id", unique: true, using: :btree

  create_table "products", force: :cascade do |t|
    t.string   "brand_name"
    t.string   "source"
    t.string   "source_id"
    t.string   "kind"
    t.string   "retailer"
    t.string   "title"
    t.string   "category"
    t.string   "url"
    t.string   "image"
    t.text     "additional_images",       default: [],                 array: true
    t.string   "price"
    t.string   "price_sale"
    t.string   "color"
    t.string   "size"
    t.string   "material"
    t.string   "gender"
    t.string   "upc"
    t.string   "mpn"
    t.string   "sku"
    t.string   "style_code"
    t.string   "item_group_id"
    t.string   "google_category"
    t.text     "description"
    t.datetime "created_at",                              null: false
    t.datetime "updated_at",                              null: false
    t.integer  "brand_id"
    t.boolean  "match",                   default: false
    t.string   "image_local"
    t.text     "additional_images_local", default: [],                 array: true
    t.boolean  "in_store",                default: false
    t.string   "price_currency"
  end

  add_index "products", ["brand_id"], name: "index_products_on_brand_id", using: :btree
  add_index "products", ["brand_name"], name: "index_products_on_brand_name", using: :btree
  add_index "products", ["color"], name: "index_products_on_color", using: :btree
  add_index "products", ["created_at"], name: "index_products_on_created_at", where: "(((source)::text = ANY ((ARRAY['shopbop'::character varying, 'eastdane'::character varying])::text[])) AND ((upc IS NULL) OR ((upc)::text = ''::text)))", using: :btree
  add_index "products", ["in_store"], name: "index_products_on_in_store", using: :btree
  add_index "products", ["match"], name: "index_products_on_match", using: :btree
  add_index "products", ["mpn"], name: "index_products_on_mpn", using: :btree
  add_index "products", ["size"], name: "index_products_on_size", using: :btree
  add_index "products", ["sku"], name: "index_products_on_sku", using: :btree
  add_index "products", ["source", "retailer"], name: "index_products_on_source_and_retailer", using: :btree
  add_index "products", ["source", "source_id"], name: "index_products_on_source_and_source_id", using: :btree
  add_index "products", ["source", "style_code"], name: "index_products_on_source_and_style_code", using: :btree
  add_index "products", ["source"], name: "index_products_on_source", using: :btree
  add_index "products", ["style_code"], name: "index_products_on_style_code", using: :btree
  add_index "products", ["title"], name: "index_products_on_title", using: :btree
  add_index "products", ["upc"], name: "index_products_on_upc", using: :btree

  create_table "stat_amounts", force: :cascade do |t|
    t.string  "key"
    t.integer "value"
    t.date    "date"
  end

  add_index "stat_amounts", ["date"], name: "index_stat_amounts_on_date", using: :btree
  add_index "stat_amounts", ["key"], name: "index_stat_amounts_on_key", using: :btree

  create_table "users", force: :cascade do |t|
    t.string   "email",                  default: "", null: false
    t.string   "encrypted_password",     default: "", null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet     "current_sign_in_ip"
    t.inet     "last_sign_in_ip"
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
    t.string   "role"
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree

  create_table "websites", force: :cascade do |t|
    t.string   "provided_url"
    t.string   "url"
    t.string   "platform"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
  end

  add_index "websites", ["platform"], name: "index_websites_on_platform", using: :btree
  add_index "websites", ["provided_url"], name: "index_websites_on_provided_url", unique: true, using: :btree
  add_index "websites", ["url"], name: "index_websites_on_url", using: :btree

end
