class GTIN

  attr_reader :gtin

  REGEXP = /\A\d+\z/

  def initialize(gtin)
    @gtin = gtin
    prepare_number
  end

  def self.process(input)
    self.new(input).process
  end

  def process
    valid? ? gtin : false
  end

  def self.valid?(input)
    self.new(input).valid?
  end

  def valid?
    numbers[-1].to_i == last_digit
  end

  def correct_last_digit
    "#{gtin[0...-1]}#{last_digit}"
  end

  private

  def last_digit
    checksum = 0
    case numbers.length
      when 8
        0.upto(numbers.length-2) do |i| checksum += numbers[i].to_i * ((i-1)%2*3 +i%2) end
      when 12
        0.upto(numbers.length-2) do |i| checksum += numbers[i].to_i * ((i-1)%2*3 +i%2) end
      when 13
        0.upto(numbers.length-2) do |i| checksum += numbers[i].to_i * (i%2*3 +(i-1)%2) end
      when 14
        0.upto(numbers.length-2) do |i| checksum += numbers[i].to_i * ((i-1)%2*3 +i%2) end
      else
        return false
    end

    (10 - checksum % 10)%10
  end

  def numbers
    gtin.to_s.gsub(/[\D]+/, '').split(//)
  end

  def prepare_number
    @gtin = @gtin.to_s.gsub(/[\D]+/, "")
    @gtin = @gtin[1,13] if @gtin.size == 14 && @gtin[0] == '0'
    @gtin = @gtin[1,12] if @gtin.size == 13 && @gtin[0] == '0'
  end

  def log(str)
    defined?(Rails) && Rails.logger ? Rails.logger.debug(str) : nil
  end
end
