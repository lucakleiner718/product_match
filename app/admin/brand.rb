ActiveAdmin.register Brand do

  permit_params :name, :synonyms_text, :in_use

  config.sort_order = 'name_asc'

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
      brand.synonyms_text
    end
    column :in_use
    # column :products do |brand|
    #   Product.where(brand_id: brand.id).size
    # end
    column 'Sources' do |brand|
      size = ProductSource.where(name: brand.names).size
      link_to_if size > 0, size, admin_product_sources_path(q: { name_in: brand.names })
    end
    actions
  end

end
