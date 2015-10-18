ActiveAdmin.register User do
  permit_params :email, :password, :password_confirmation, :role

  controller do
    def update
      params[:user].delete :password if params[:user][:password].blank?
      params[:user].delete :password_confirmation if params[:user][:password_confirmation].blank?
      super
    end
  end

  index do
    selectable_column
    column :email
    column :current_sign_in_at
    column :sign_in_count
    column :created_at
    column :role
    actions
  end

  filter :email
  filter :current_sign_in_at
  filter :sign_in_count
  filter :created_at

  form do |f|
    f.inputs "Admin Details" do
      f.input :email
      f.input :password, required: false
      f.input :password_confirmation, required: false
      f.input :role, as: :select, collection: [['Admin', 'admin']]
    end
    f.actions
  end

end
