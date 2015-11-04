ActiveAdmin.register ProductSource do

  permit_params :name, :source_name, :source_id, :brand_id, :period

  index do
    selectable_column
    column :name
    column :source_name
    column :source_id
    column :brand
    column 'Regular update' do |it|
      if it.period && it.period > 0
        "#{it.period} day(s)"
      else
        'Manual'
      end
    end
    column :collected_at
    column :collect_status do |ps|
      "#{status_tag(ps.collect_status_code || :ok)}#{": #{ps.collect_status_message}" if ps.collect_status_message.present?}"
    end
    actions
    column 'Source' do |item|
      case item.source_name
        when 'popshops'
          link_to 'Link', Import::Popshops.new.build_url(brand: item.source_id), target: :_blank
        when 'website'
          link_to 'Link', Module.const_get("Import::#{item.source_id.titleize}").new.baseurl, target: :_blank rescue nil
        when 'shopbop'
          link_to 'Link', item.source_id, target: :_blank
      end
    end
  end

  form do |f|
    f.inputs do
      f.input :name, hint: 'Can be Brand name either just a name for shop. Brand name should be exact like added in brands section.'
      f.input :source_name, collection: [['Popshops', 'popshops'], ['Linksynergy', 'linksynergy'], ['Shopbop', 'shopbop'], ['Website', 'website']]
      f.input :source_id, label: 'Source ID'
      f.input :brand, collection: Brand.in_use.order(:name)
      f.input :period, label: 'Regular update', as: :select, collection: [['Every day', 1], ['Every week', 7], ['Every month', 30], ['Manual', 0]], prompt: false
    end
    f.actions
  end

  filter :name
  filter :source_name
  filter :source_id, label: 'Source ID'
  filter :period, label: 'Regular update', as: :select, collection: [['Every day', 1], ['Every week', 7], ['Every month', 30], ['Manual', 0]]
  filter :status

end
