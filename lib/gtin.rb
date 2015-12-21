class GTIN

  def initialize(gtin)
    @gtin = gtin
    prepare_number
  end

  # @return correct upc (can be modified) or false if upc is wrong
  def self.process(input)
    instance = self.new(input)
    instance.process
  end

  def process
    if valid_gtin?
      gtin
    else
      false
    end
  end

  private

  attr_reader :gtin

  def prepare_number
    @gtin = @gtin.to_s.gsub(/[\D]+/, "")
    @gtin = @gtin[1,13] if @gtin.size == 14 && @gtin[0] == '0'
    @gtin = @gtin[1,12] if @gtin.size == 13 && @gtin[0] == '0'
  end

  def valid_gtin?
    numbers = gtin.to_s.gsub(/[\D]+/, "").split(//)

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

    last_digit = (10 - checksum % 10)%10
    valid = numbers[-1].to_i == last_digit
    unless valid
      puts "Last digit should be #{last_digit} instead of #{numbers[-1].to_i}"
    end
    valid
  end

end