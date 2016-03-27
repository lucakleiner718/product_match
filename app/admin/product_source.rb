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
        if it.period < 24*60*60
          "#{it.period_hours} hour(s)"
        else
          "#{it.period_days} day(s)"
        end
      else
        'Manual'
      end
    end
    column :collected_at
    column :collect_status do |ps|
      status_tag(ps.collect_status_code || :ok, title: ps.collect_status_message)
    end
    actions
    column 'Source' do |ps|
      case ps.source_name
        when 'amazon_ad_api'
          link_to 'Full', Import::Amazon.source_url(ps.source_id), target: :_blank
        when 'popshops'
          link_to 'Full', Import::Popshops.new.build_url_params(brand: ps.source_id), target: :_blank
        when 'popshops_merchant'
          link_to 'Full', Import::Popshops.new.build_url_params(merchant: ps.source_id), target: :_blank
        when 'website'
          link_to 'Full', Module.const_get("Import::#{ps.source_id.titleize}").new.baseurl, target: :_blank rescue nil
        when 'shopbop', 'eastdane', 'cj'
          link_to 'Full', ps.source_id, target: :_blank
        when "linksynergy"
          [
            link_to('Full', Import::Linksynergy.build_file_url(ps.source_id, type: :full), target: :_blank),
            link_to('Delta', Import::Linksynergy.build_file_url(ps.source_id, type: :delta), target: :_blank)
          ].join('&nbsp;').html_safe
      end
    end
  end

  form do |f|
    f.inputs do
      f.input :name, hint: 'Can be Brand name either just a name for shop. Brand name should be exact like added in brands section.'
      f.input :source_name, collection: ProductSource::SOURCES
      f.input :source_id, label: 'Source ID'
      f.input :brand, collection: Brand.in_use.order(:name)
      f.input :period, label: 'Regular update', as: :select, collection: ProductSource::PERIODS, prompt: false, selected: (f.object.new_record? ? 7.days.to_i : f.object.period), include_blank: false
    end
    f.actions
  end

  filter :name
  filter :source_name
  filter :source_id, label: 'Source ID'
  filter :period, label: 'Regular update', as: :select, collection: ProductSource::PERIODS
  filter :status

  scope :all, default: true
  scope(:shopbop) { |scope| scope.where(source_name: [:shopbop, :eastdane])}

end
