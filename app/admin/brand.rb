ActiveAdmin.register Brand do

  permit_params :name, :synonyms_text, :in_use

  config.sort_order = 'name_asc'

  filter :name
  filter :synonyms
  filter :in_use

  controller do
    def scoped_collection
      Brand.includes(:sources)
    end
  end

  scope :in_use, default: true
  scope :all

  form do |f|
    f.inputs do
      f.input :name
      f.input :synonyms_text, hint: 'Separate synonyms with only comma', label: 'Synonyms'
      f.input :in_use
    end
    f.actions
  end

  index do
    selectable_column
    column :name
    column :synonyms do |brand|
      brand.synonyms.join(', ')
    end
    column :in_use
    column :products do |brand|
      Product.where(brand_id: brand.id).size
    end
    column 'Sources' do |brand|
      size = brand.sources.size
      link_to_if size > 0, size, admin_product_sources_path(q: { brand_id_eq: brand.id })
    end
    actions
  end

  batch_action :merge_to, confirm: 'Select brand you want to merge selected brands', form: {
      brand_id: Brand.in_use.map{|b| [b.name, b.id]}.sort,
    } do |ids, inputs|
    brand = Brand.find(inputs['brand_id'])
    brand.merge_with! ids
    redirect_to :back
  end

end
