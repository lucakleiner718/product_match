class Import::Platform::Bop < Import::Base
  include Import::FileImport

  def csv_col_sep; ','; end

  def self.perform(url=nil, force=false)
    instance = self.new
    instance.perform(url, force)
  end

  def perform(url=nil, force=false)
    raise Exception, "Should be overridden by parent class"
  end

  private

  def process_create(to_create)
    if to_create.size > 0
      keys = to_create.first.keys
      keys += [:match, :created_at, :updated_at]
      tn = Time.now.utc.strftime('%Y-%m-%d %H:%M:%S')
      sql = "INSERT INTO products
                (#{keys.join(',')})
                VALUES #{to_create.map{|r| "(#{r.values.concat([true, tn, tn]).map{|el| Product.sanitize(el.is_a?(Array) ? "{#{el.join(',')}}" : el)}.join(',')})"}.join(',')}
                RETURNING id"
      resp = Product.connection.execute sql
      resp.map{|r| r['id'].to_i}
    else
      []
    end
  end
end
