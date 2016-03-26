class Suggestion

  WEIGHTS = {
    color: 5,
    size: 2,
    title: 5
  }
  GENDER_WEIGHT = 5
  PRICE_WEIGHT  = 2
  STYLE_CODE_WEIGHT = 10
  SIMILARITY_MIN = 40

  def initialize(product_id)
    @product = Product.find(product_id)
    load_kinds
  end

  def build
    # do not generate suggestions if upc already detected or brand is blank
    return false if with_upc? || product.brand.try(:name).blank?

    exists_suggestions = ProductSuggestion.where(
      product_id: product.id).index_by{|el| el.suggested_id}

    to_create = []
    actual_list = []

    upc_patterns = product.upc_patterns

    related_products.each do |suggested|
      percentage = similarity_to(suggested, upc_patterns)
      next if percentage < SIMILARITY_MIN

      suggestion = exists_suggestions[suggested['id'].to_i]
      actual_list << suggested['id'].to_i

      if suggestion
        suggestion.percentage = percentage
        suggestion.upc_patterns = upc_patterns
        suggestion.save! if suggestion.changed?
      else
        to_create << [
          product.id, suggested['id'], percentage,
          "{#{upc_patterns.join(',')}}",
          suggested['price'], suggested['price_sale']
        ]
      end
    end

    actual_list.uniq!

    not_actual = exists_suggestions.values.uniq.map(&:suggested_id) - actual_list
    if not_actual.size > 0
      ProductSuggestion.where(product_id: product.id, suggested_id: not_actual).delete_all
    end

    create_items(to_create)
    actual_list.size
  end

  private

  attr_reader :product, :kinds

  # @returns [Integer] similarity percentage of initial product and suggested
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
    if upc_patterns.select{|upc| suggested['upc'] =~ /^#{upc}\d+$/ }.size > 0
      @params_amount += STYLE_CODE_WEIGHT
      STYLE_CODE_WEIGHT
    end
  end

  def title_similarity(suggested)
    strings_similarity(product.title, suggested['title']) * WEIGHTS[:title]
  end

  def strings_similarity(string_a, string_b)
    ratio = nil

    if string_a.blank?
      ratio = 1
    elsif string_b.blank?
      ratio = 0
    end

    string_a_parts = product_title_parts(string_a)
    string_b_parts = product_title_parts(string_b)

    if !ratio && string_a_parts.sort.join == string_b_parts.sort.join
      ratio = 1
    end

    unless ratio
      similar_words = []
      kinds.each do |(_name, synonyms)|
        has_word_a = false
        has_word_b = false

        synonyms.each do |synonym|
          if !has_word_a && (synonym.split & string_a_parts).size == synonym.split.size
            has_word_a = synonym
            break
          end
        end

        if has_word_a
          synonyms.each do |synonym|
            if (synonym.split & string_b_parts).size == synonym.split.size
              has_word_b = synonym
              break
            end
          end

          if has_word_b
            similar_words << [has_word_a, has_word_b]
            string_a_parts -= [has_word_a]
            string_b_parts -= [has_word_b]
          end
        end
      end

      ratio =
        if string_a_parts.size > 0 || similar_words.size > 0
          ((string_a_parts & string_b_parts).size + similar_words.size) / (string_a_parts.size.to_f + similar_words.size)
        else
          1
        end
    end

    ratio
  end

  def color_similarity(suggested)
    color_p = product.color
    color_s = suggested['color']
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
    if suggested['size'].present? && product.size.present?
      size_s = suggested['size'].gsub(/\s/, '').downcase
      size_p = product.size.gsub(/\s/, '').downcase

      basic_sizes = [
        ['2xs', 'xxs', 'xxsmall', 'xxsml'],
        ['xs', 'xsmall', 'xsml', 'extra small'],
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
      exact = true if size_s == size_p || size_s.sub(/\sm$/i, '') == size_p.sub(/\sm$/i, '')
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
      if suggested['size'].blank? && product.size.present? && product.size.downcase == 'one size'
        WEIGHTS[:size]
      end
    end
  end

  def price_similarity(suggested)
    return 0 if suggested['price'].blank? && product.price.blank?

    @params_amount += PRICE_WEIGHT

    return 0 if suggested['price'].blank? || product.price.blank?

    suggested_price = price_m(suggested['price'], suggested['price_currency'])
    suggested_price_sale = price_m(suggested['price_sale'], suggested['price_currency'])

    product_price = price_m(product.price, product.price_currency)
    product_price_sale = price_m(product.price_sale, product.price_currency)

    suggested_prices = [suggested_price, suggested_price_sale].compact.map(&:to_i).uniq
    product_prices = [product_price, product_price_sale].compact.map(&:to_i).uniq
    ratio =
      if (suggested_prices & product_prices).size > 0
        1
      else
        diff = (suggested_prices.min - product_prices.min).abs / product_price.to_f
        diff = 1 if diff > 1
        diff = 1 - diff

        diff
      end

    ratio * PRICE_WEIGHT
  end

  def gender_similarity(suggested)
    if product.gender.present? && suggested['gender'].present?
      if suggested['gender'] != product.gender
        @params_amount += GENDER_WEIGHT
        0
      end
    end
  end

  # @return [ActiveRecord::Relation] AR query to find related products
  def related_products
    return @related_products if @related_products

    query = Product.not_matching.where(brand_id: product.brand.id).
      with_upc.with_image

    title_parts = product_title_parts(product.title)

    # search products with synonyms for main category
    to_search = kinds.values.select do |synonyms|
      synonyms.select { |synonym| (synonym.singularize.split & title_parts).size == synonym.split.size }.size > 0
    end

    to_search = to_search.flatten.uniq

    if to_search.size > 0
      synonyms_query = "to_tsvector(products.title) @@ to_tsquery('#{
        to_search.uniq.map do |el|
          el.split(' ').size > 1 ? "(#{el.split(' ').join(' & ')})" : el
        end.join(' | ')}')"

      # synonyms_query = to_search.map{|el| "products.title ILIKE #{Product.sanitize "%#{el}%"}"}.join(' OR ')

      query = query.where(synonyms_query)
    elsif title_parts.size > 0
      synonyms_query = title_parts.map{|el| "products.title ILIKE #{Product.sanitize "%#{el}%"}"}.join(' OR ')
      query = query.where(synonyms_query)
    end

    # remove from list product with upc, if shopbop's product already have same upc
    query = query.joins("LEFT JOIN products AS products_upc ON products_upc.upc=products.upc AND products_upc.source IN ('shopbop', 'eastdane')").where('products_upc.id is null')

    items = Product.connection.execute(query.to_sql).to_a
    items = add_items_by_siblings(items)

    items = items.uniq.select{|item| have_valid_upc?(item)}

    @related_products = items
  end

  def create_items(to_create)
    return if to_create.size == 0

    columns = [:product_id, :suggested_id, :percentage, :upc_patterns, :price, :price_sale]

    to_create = to_create.sort{|a, b| b[2] <=> a[2]}[0...100] if to_create.size > 100

    begin
      ProductSuggestion.import(columns, to_create)
    rescue ActiveRecord::RecordNotUnique => e
      to_create.each do |row|
        begin
          ProductSuggestion.create!(Hash[columns.zip(row)])
        rescue ActiveRecord::RecordNotUnique => e
        end
      end
    end
  end

  def add_items_by_siblings(items)
    similar_products = Product.connection.execute("""
      SELECT p4.*
      FROM products AS products
      JOIN products AS p2 ON p2.style_code=products.style_code AND p2.source=products.source AND p2.id != products.id AND p2.upc IS NOT NULL
      JOIN products AS p3 ON p3.upc=p2.upc AND p3.source NOT IN ('shopbop', 'eastdane') AND p3.brand_id=p2.brand_id AND p3.style_code IS NOT NULL AND p3.style_code != ''
      JOIN products AS p4 ON p4.style_code=p3.style_code AND p4.id != p3.id AND p4.source=p3.source AND p4.upc IS NOT NULL
      LEFT JOIN products AS products_upc ON products_upc.upc=p4.upc AND products_upc.source IN ('shopbop', 'eastdane')
      WHERE products.id=#{product.id} AND products_upc.id is null
    """).to_a.uniq

    if items.size > 0
      items_ids = Set.new(items.map{|item| item['id']})
      similar_products.reject{|sp| items_ids.member?(sp['id'])}
    end

    items + similar_products
  end

  def load_kinds
    @kinds = YAML.load_file('config/products_kinds.yml')
  end

  def have_valid_upc?(suggested)
    GTIN.new(suggested['upc']).valid? && !(suggested['source'] == 'amazon_ad_api' && suggested['upc'] =~ /^7010/)
  end

  def with_upc?
    product.upc.present? || ProductUpc.where(product_id: product.id).where.not(upc: nil).exists?
  end

  def price_m(price, currency='USD')
    return nil unless price
    Money.new(price.to_f*100, currency).exchange_to("USD")
  end

  def product_title_parts(title)
    title.gsub(/[,\.\-\(\)\'\"\!]/, ' ').split(/\s/).
      select{|el| el.strip.present? }.map{|el| el.downcase.strip}.
      select{|el| el.size > 2} - ['the', 'and', 'womens', 'mens', 'size'].
      map{|item| item.singularize}.
      uniq
  end
end
