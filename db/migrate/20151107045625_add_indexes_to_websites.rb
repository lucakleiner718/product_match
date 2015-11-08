class AddIndexesToWebsites < ActiveRecord::Migration
  def change
    add_index :websites, :provided_url, unique: true
    add_index :websites, :url
    add_index :websites, :platform
  end
end
