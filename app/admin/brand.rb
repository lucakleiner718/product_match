ActiveAdmin.register Brand do

  permit_params :name, :synonyms_text, :in_use

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
    column :created_at
    column :updated_at
    actions
  end

end
