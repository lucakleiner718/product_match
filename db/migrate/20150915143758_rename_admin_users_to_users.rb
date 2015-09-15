class RenameAdminUsersToUsers < ActiveRecord::Migration
  def change
    rename_table :admin_users, :users
    add_column :users, :is_admin, :boolean, default: false
  end
end
