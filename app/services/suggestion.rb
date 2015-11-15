class Suggestion

  WEIGHTS = {
    color: 5,
    size: 2,
    title: 5,
    price: 2
  }
  GENDER_WEIGHT = 5
  STYLE_CODE_WEIGHT = 10
  EXCLUDE_SOURCES = [
    'lordandtaylor.com'
  ]

  def initialize(product_id, rewrite=false)
    @product = Product.find(product_id)
    @rewrite = rewrite
  end

  def build
    # do not generate suggestions if upc already detected
    if product.upc.present? || ProductUpc.where(product_id: product.id).first.try(:upc)
      return false
    end

    return false unless product.brand.try(:name)

    if rewrite
      ProductSuggestion.where(product_id: product.id).delete_all
    end

    to_create = process_related_products
    create_items(to_create)
    to_create.size
  end

  private

  attr_reader :product, :rewrite

  def process_related_products
    related_products = build_related_products

    if rewrite
      exists = {}
    else
      exists = ProductSuggestion.where(
        product_id: product.id,
        suggested_id: related_products.map(&:id)
      ).inject({}){|obj, el| obj["#{el.product_id}_#{el.suggested_id}"] = el; obj}
    end

    to_create = []

    upc_patterns = product.upc_patterns

    related_products.find_each do |suggested|
      percentage = similarity_to(suggested, upc_patterns)
      ps = exists["#{product.id}_#{suggested.id}"]
      if percentage && percentage > 50
        if ps
          ps.percentage = percentage
          ps.upc_patterns = upc_patterns
          ps.save if ps.changed?
        else
          to_create << {
            product_id: product.id, suggested_id: suggested.id, percentage: percentage,
            upc_patterns: "{#{upc_patterns.join(',')}}",
            price: suggested.price, price_sale: suggested.price_sale,
            created_at: Time.now, updated_at: Time.now
          }
        end
      end
    end

    to_create
  end

  def similarity_to(suggested, upc_patterns)
    @params_amount = WEIGHTS.values.sum
    params_count = []

    params_count << title_similarity(suggested)
    params_count << color_similarity(suggested)
    params_count << size_similarity(suggested)
    params_count << price_similarity(suggested)
    params_count << gender_similarity(suggested)
    params_count << style_code_similarity(suggested, upc_patterns) if upc_patterns.size > 0

    (params_count.select{|el| el.present?}.sum/@params_amount.to_f * 100).to_i
  end

  def style_code_similarity(suggested, upc_patterns)
    if upc_patterns.select{|upc| suggested.upc =~ /^#{upc}$/ }.size > 0
      @params_amount += STYLE_CODE_WEIGHT
      STYLE_CODE_WEIGHT
    end
  end

  def title_similarity(suggested)
    title_parts = product.title.split(/\s/).map{|el| el.downcase.gsub(/[^0-9a-z]/i, '')}.select{|el| el.size > 2}
    title_parts -= ['the', '&', 'and', 'womens']

    suggested_title_parts = suggested.title.split(/\s/).map{|el| el.downcase.gsub(/[^0-9a-z]/i, '')}.select{|r| r.present?}

    multiplier = [['panty', 'panties'], ['short', 'shorts'], ['boot', 'boots', 'booties']]
    multiplier.each do |ar|
      if (title_parts & ar).size > 0 && (suggested_title_parts & ar)
        title_parts -= ar
        suggested_title_parts -= ar

        title_parts << ar.first
        suggested_title_parts << ar.first
      end
    end

    title_parts.uniq!
    suggested_title_parts.uniq!

    title_parts_size = title_parts.size

    (title_parts_size > 0 ? title_parts.select{|item| item.in?(suggested_title_parts)}.size / title_parts_size.to_f : 1) * WEIGHTS[:title]
  end

  def color_similarity(suggested)
    color_p = product.color
    color_s = suggested.color
    if color_s.present? && color_p.present?
      ratio = nil
      if color_s.gsub(/[^a-z]/i, '').downcase == color_p.gsub(/[^a-z]/i, '').downcase
        ratio = 1
      else
        color_s_ar = color_s.gsub(/\s/, '').downcase.split(/[\/,]/).map{|el| el.strip}
        color_p_ar = color_p.gsub(/\s/, '').downcase.split(/[\/,]/).map{|el| el.strip}

        if color_s_ar.size == 2 && color_p_ar.size == 1
          if color_s_ar.first == color_p_ar.first || color_s_ar.last == color_p_ar.first
            ratio = 0.99
          end
        elsif color_s_ar.size > 2 && color_s_ar.size == color_p_ar.size
          if color_s_ar.sort.join == color_p_ar.sort.join
            ratio = 0.99
          end
        end
      end

      unless ratio
        color_s_ar = color_s.downcase.split(/[\s\/,]/).map{|el| el.strip}.select{|el| el.present?}
        color_p_ar = color_p.downcase.split(/[\s\/,]/).map{|el| el.strip}.select{|el| el.present?}
        ratio = (color_p_ar & color_s_ar).size / (color_s_ar + color_p_ar).uniq.size.to_f
      end

      ratio * WEIGHTS[:color]
    end
  end

  def size_similarity(suggested)
    if suggested.size.present? && product.size.present?
      size_s = suggested.size.gsub(/\s/, '').downcase
      size_p = product.size.gsub(/\s/, '').downcase

      basic_sizes = [
        ['2xs', 'xxs', 'xxsmall', 'xxsml'],
        ['xs', 'xsmall', 'xsml'],
        ['petite', 'p'],
        ['small', 's'],
        ['medium', 'm'],
        ['large', 'l'],
        ['xlarge', 'xl', 'xlrg'],
        ['xxl', '2xlarge', 'xxlarge'],
        ['3xlarge', 'xxxlarge', 'xxxl'],
        ['4xlarge', 'xxxxlarge', 'xxxxl'],
        ['5xlarge', 'xxxxxl', 'xxxxxlarge'],
        ['onesize', 'o/s', '1sz'],
      ]
      (1..10).each do |i|
        basic_sizes << ["#{i}1/2", "#{i}.5"]
      end

      exact = false
      exact = true if size_s == size_p
      unless exact
        basic_sizes.each do |options|
          if size_s.gsub('-', '').in?(options) && size_p.gsub('-', '').in?(options)
            exact = true
            break
          end
        end
      end

      if exact
        WEIGHTS[:size]
      elsif size_s =~ /us/ && size_s =~ /eu/
        eu_size = size_s.match(/(\d{1,2}\.?\d?)eu/i)
        if eu_size && size_p == eu_size[1]
          WEIGHTS[:size]
        end
      end
    else
      if suggested.size.blank? && product.size.present? && product.size.downcase == 'one size'
        WEIGHTS[:size]
      end
    end
  end

  def price_similarity(suggested)
    suggested_prices = [suggested.price, suggested.price_sale].compact.uniq
    product_prices = [product.price, product.price_sale].compact.uniq
    ratio =
      if (suggested_prices & product_prices).size > 0
        1
      elsif suggested.price.present? && product.price.present?
        diff = (suggested.price.to_i - product.price.to_i).abs / product.price.to_f
        diff = 1 if diff > 1
        diff = 1 - diff

        diff
      else
        0
      end

    ratio * WEIGHTS[:price]
  end

  def gender_similarity(suggested)
    if suggested.gender.present?
      @params_amount += GENDER_WEIGHT
      if suggested.gender == product.gender
        GENDER_WEIGHT
      end
    end
  end

  def build_related_products
    brand_name = product.brand.try(:name)
    brand = Brand.get_by_name(brand_name) || Brand.create(name: brand_name)

    rp = Product.not_matching.where('products.source NOT IN (?)', EXCLUDE_SOURCES)
           .where(brand_id: brand.id).with_upc

    title_parts = product.title.gsub(/[,\.\-\(\)\'\"]/, '').split(/\s/).map{|el| el.downcase.strip}
                    .select{|el| el.size > 2} - ['the', '&', 'and', 'womens']
    rp = rp.where(title_parts.map{|el| "products.title ILIKE #{Product.sanitize "%#{el}%"}"}.join(' OR '))

    rp = rp.joins("LEFT JOIN products AS p1 ON p1.upc IS NOT NULL AND p1.upc != ''
                   AND p1.upc=products.upc AND p1.id != products.id
                   AND p1.source IN (#{Product::MATCHED_SOURCES.map{|el| Product.sanitize el}.join(',')})")
           .where('p1.id is null')

    rp
  end

  def create_items(to_create)
    if to_create.size > 0
      begin
        ProductSuggestion.connection.execute("
          INSERT INTO product_suggestions (#{to_create.first.keys.join(',')})
          VALUES #{to_create.map{|r| "(#{r.values.map{|el| ProductSuggestion.sanitize el}.join(',')})"}.join(',')}
          ")
      rescue ActiveRecord::RecordNotUnique => e
        to_create.each do |row|
          row.delete :created_at
          row.delete :updated_at
          ProductSuggestion.create row rescue nil
        end
      end
    end
  end

end