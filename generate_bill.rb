require 'csv'
require 'erb'
require 'pp'
require 'time'

require_relative 'duration_spreader'
require_relative 'calendar_bill_manager'
require_relative 'period_of_work'

Encoding.default_external = Encoding.find('UTF-8')

accepted, f_day, l_day = CalendarBillManager.new(ARGV[0]).extract_events
puts "ACCEPTED:"
puts "_________"
accepted.each { |ev| puts "Event: #{ev.summary} st #{ev.dtstart} dt #{ev.dtend}" }

pwork = PeriodOfWork.new(f_day, l_day)
pwork.add_events(accepted)
pwork.spread_durations
months = pwork.split_by_month

def dates_to_string(st, ed)
  if st == ed
    st.strftime("%d/%m/%Y")
  else
    st.strftime("%d/%m/%y") + " - " + ed.strftime("%d/%m/%y")
  end
end

def money_format(f)
  sprintf("£%.2f", f)
end

def timespan_label(first, last)
  fdom = Date.new(first.year, first.month, 1)
  ldom = Date.new(last.year, last.month, -1)
  if first == fdom and last == ldom
    first.strftime("%B")
  else
    first.strftime("%B %-d to ") + last.strftime("%-d")
  end
end

@vat_percent = 20.0
@daily_rate = 200.0

@billable_months = months.map do |m|
  billable_month = {}
  items = m.to_billable_items.map do |name, data|
    billable = {}
    billable[:description] = name
    billable[:date_string] = dates_to_string(data[:st], data[:ed])
    billable[:amount] = data[:amount]
    billable[:pre_tax_total] = @daily_rate * billable[:amount]
    billable[:vat] = @vat_percent / 100.0 * billable[:pre_tax_total]
    billable[:total] = billable[:pre_tax_total] + billable[:vat]
    billable
  end
  billable_month[:label] = timespan_label(m.begin, m.end)
  billable_month[:sub_total] = items.inject(0) { |sum, item| sum + item[:pre_tax_total] }
  billable_month[:vat_total] = items.inject(0) { |sum, item| sum + item[:vat] }
  billable_month[:grand_total] = billable_month[:sub_total] + billable_month[:vat_total]
  items.each do |item|
    item[:amount] = item[:amount].round(3)
    [:pre_tax_total, :vat, :total].each { |s| item[s] = money_format(item[s]) }
  end
  billable_month[:items] = items
  billable_month
end

@sub_total = @billable_months.inject(0) { |sum, m| sum + m[:sub_total] }
@vat_total = @billable_months.inject(0) { |sum, m| sum + m[:vat_total] }
@grand_total = @sub_total + @vat_total

@billable_fields = [:description, :date_string, :amount, :pre_tax_total, :vat, :total]

@billable_format_rules = {
  description: {title: "Description", classes: ""},
  date_string: {title: "Dates", classes: "text-center"},
  amount: {title: "Days", classes: "text-right"},
  pre_tax_total: {title: "Pre-Tax Total", classes: "text-right"},
  vat: {title: "VAT", classes: "text-right"},
  total: {title: "Total", classes: "text-right"}
}

puts @billable_items

erb = ERB.new(File.read("./bill.erb"))

File.write("./result.html", erb.result(binding))
