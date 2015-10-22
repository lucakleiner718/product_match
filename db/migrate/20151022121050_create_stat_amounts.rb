class CreateStatAmounts < ActiveRecord::Migration
  def change
    create_table :stat_amounts do |t|
      t.string :key
      t.integer :value
      t.date :date
    end

    add_index :stat_amounts, :key
    add_index :stat_amounts, :date
  end
end
