ActiveAdmin.register ProductSource do

  permit_params :name, :source_name, :source_id

  index do
    selectable_column
    column :name
    column :source_name
    column :source_id
    column :collected_at
    actions
  end

  form do |f|
    f.inputs do
      f.input :name, hint: 'Can be Brand name either just a name for shop. Brand name should be exact like added in brands section.'
      f.input :source_name, collection: [['Popshops', 'popshops'], ['Linksynergy', 'linksynergy']]
      f.input :source_id, label: 'Source ID'
    end
    f.actions
  end

end
