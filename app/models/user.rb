class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, 
         :recoverable, :rememberable, :trackable, :validatable

  ROLES = %w(manager admin)

  def is_admin?
    self.role == 'admin'
  end

  def manager?
    self.role == 'manager'
  end

  def regular?
    self.role.blank?
  end
end
