class Website < ActiveRecord::Base

  def self.export file
    data = CSV.read(file).map(&:first)
    csv_string = CSV.generate do |csv|
      Website.where(provided_url: data).each do |w|
        csv << [w.provided_url, w.url, w.platform]
      end
    end
    File.write file, csv_string
  end

end
