ActiveAdmin.register ProductSource do

  permit_params :brand_name, :source_name, :source_id

  index do
    selectable_column
    column :brand_name
    column :source_name
    column :source_id
    column :collected_at
    actions
  end

  form do |f|
    f.inputs do
      f.input :brand_name, hint: 'Should be Brand name exact as in Brands section or "multiple"'
      f.input :source_name, collection: [['Popshops', 'popshops'], ['Linksynergy', 'linksynergy']]
      f.input :source_id, label: 'Source ID'
    end
    f.actions
  end

end
