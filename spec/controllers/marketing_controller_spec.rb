require 'rails_helper'

RSpec.describe MarketingController, type: :controller do

  describe "GET #index", pending: true do
    it "returns http success" do
      get :index
      expect(response).to have_http_status(:success)
    end
  end

end
