ActiveAdmin.register_page "Brand Duplicates" do
  menu label: 'Duplicates', parent: 'Brands'
  content do
    brand_duplicates = BrandDuplicate.order(:target_brand_id).actual.includes(:target, :duplicate)
    render partial: 'brand_duplciates', locals: { brand_duplicates: brand_duplicates }
  end

  page_action :update, method: :post do
    duplicate = BrandDuplicate.find(params[:duplicate_id])
    if params[:same] == 'yes'
      id = duplicate.duplicate.id
      duplicate.target.merge_with!([id])
      duplicate.update processed: true, processed_at: Time.now
      BrandDuplicate.where(duplicate_brand_id: id).delete_all
    else
      duplicate.update processed: false, processed_at: Time.now
    end
    render json: { }
  end
end