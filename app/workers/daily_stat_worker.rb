class DailyStatWorker

  include Sidekiq::Worker
  sidekiq_options unique: true, queue: :critical

  def perform
    date = Date.current

    total_size = Product.matching.size
    sa = StatAmount.where(date: date, key: 'shopbop_total').first_or_initialize
    sa.value = total_size
    sa.save if sa.changed?

    not_matched_size = Product.matching.without_upc.size
    sa = StatAmount.where(date: date, key: 'not_matched_size').first_or_initialize
    sa.value = not_matched_size
    sa.save if sa.changed?

    total_size = Product.matching.where(in_store: true).size
    sa = StatAmount.where(date: date, key: 'shopbop_total_published').first_or_initialize
    sa.value = total_size
    sa.save if sa.changed?

    not_matched_size = Product.matching.where(in_store: true).without_upc.size
    sa = StatAmount.where(date: date, key: 'not_matched_size_published').first_or_initialize
    sa.value = not_matched_size
    sa.save if sa.changed?
  end

end