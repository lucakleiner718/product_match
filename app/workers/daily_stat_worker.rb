class DailyStatWorker

  include Sidekiq::Worker
  sidekiq_options unique: true, queue: :critical

  def perform
    current_date = Date.current

    total_size = Product.shopbop.size
    sa = StatAmount.where(date: current_date, key: 'shopbop_total').first_or_initialize
    sa.value = total_size
    sa.save if sa.changed?

    not_matched_size = Product.shopbop.without_upc.size
    sa = StatAmount.where(date: current_date, key: 'not_matched_size').first_or_initialize
    sa.value = not_matched_size
    sa.save if sa.changed?
  end

end