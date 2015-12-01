# source of rates http://api.fixer.io/latest?base=USD
rates = JSON.parse %|
{"AUD":1.3884,"BGN":1.8486,"BRL":3.7201,"CAD":1.3347,"CHF":1.0302,"CNY":6.3941,"CZK":25.543,"DKK":7.0515,
"GBP":0.66437,"HKD":7.7506,"HRK":7.2051,"HUF":294.97,"IDR":13827.0,"ILS":3.8875,"INR":66.772,"JPY":122.64,
"KRW":1154.8,"MXN":16.55,"MYR":4.2675,"NOK":8.6848,"NZD":1.5302,"PHP":47.184,"PLN":4.0294,"RON":4.2029,
"RUB":66.157,"SEK":8.7353,"SGD":1.4109,"THB":35.89,"TRY":2.9173,"ZAR":14.319,"EUR":0.94518}|
def_bank = Money::Bank::VariableExchange.new
rates.each do |key, rate|
  def_bank.add_rate("USD", key, rate)
  def_bank.add_rate(key, "USD", 1/rate)
end
Money.default_bank = def_bank
