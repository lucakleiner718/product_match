class Website < ActiveRecord::Base

  def self.export file
    data = CSV.read(file).map(&:first)
    websites = Website.where(provided_url: data).inject({}){|obj, w| obj[w.provided_url] = w; obj}
    csv_string = CSV.generate do |csv|
      data.each do |url|
        w = websites[url]
        if w
          csv << [w.provided_url, w.url, w.platform]
        else
          csv << [url]
        end
      end
    end
    File.write file, csv_string
  end

end
