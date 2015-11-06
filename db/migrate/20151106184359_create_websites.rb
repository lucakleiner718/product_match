class CreateWebsites < ActiveRecord::Migration
  def change
    create_table :websites do |t|
      t.string :provided_url
      t.string :url
      t.string :platform

      t.timestamps null: false
    end
  end
end
