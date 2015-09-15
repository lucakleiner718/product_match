class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_action :authenticate_user!

  def authenticate_admin_user!
    return false unless authenticate_user! || current_user.is_admin?
    true
  end

  def access_denied exception
    redirect_to root_path, alert: "You don't have access to admin"
  end
end
