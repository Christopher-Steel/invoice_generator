require 'csv'
require 'erb'
require 'icalendar'
require 'pp'
require 'time'

def events_for_timespan(first_day, last_day)
  cal_file = File.open(ARGV[0])
  cal = Icalendar::Calendar.parse(cal_file).first

  accepted = []
  rejected = []
  cal.events.each do |ev|
    st = ev.dtstart
    st = st.value.to_date unless st.nil?
    ed = ev.dtend
    ed = ed.value.to_date unless ed.nil?
    if st >= first_day && ed <= last_day
      accepted << ev
    else
      rejected << "reject st|#{st} ed|#{ed} #{ev.summary}"
    end
  end
  if (ARGV.length > 1)
    puts "REJECTED:"
    puts "_________"
    puts rejected
  end
  accepted
end

def duration_from_summary(event)
  if /^(\d+(\.\d+)?).*$/ =~ event.summary
    return $1.to_f
  end
  nil
end

def name_from_summary(event)
  if /^\d+(\.\d+)?\s*(.*)$/ =~ event.summary
    return $2
  end
  return event.summary
end

f_day = Date.parse("2017-10-18T:00:00:00+00:00Z")
l_day = Date.parse("2017-11-25T:00:00:00+00:00Z")

accepted = events_for_timespan(f_day, l_day)
puts "ACCEPTED:"
puts "_________"
accepted.each { |ev| puts "Event: #{ev.summary} st #{ev.dtstart} dt #{ev.dtend}" }

days = {}
(f_day..l_day).each { |d| days[d] = [] }

def affect_dates_for_event(days, ev)
  st = ev.dtstart
  st = st.value.to_date unless st.nil?
  ed = ev.dtend
  ed = ed.value.to_date unless ed.nil?
  timespan = (st...ed)
  duration = duration_from_summary(ev)
  duration /= timespan.count unless duration.nil?
  timespan.each do |d|
    days[d] << { name: name_from_summary(ev), duration: duration }
  end
  days
end

accepted.each do |ev|
  days = affect_dates_for_event(days, ev)
end

def spread_durations(days)
  spread_days = {}
  days.each do |k, d|
    wdur = []
    wodur = []
    d.each do |ev|
        if ev[:duration].nil?
          wodur << ev
        else
          wdur << ev
        end
    end
    dleft = 1.0
    wdur.each do |ev|
      dleft -= ev[:duration]
      STDERR.puts "Too many durationed events on day #{k}" if dleft < 0
    end
    wodur.map do |ev|
      ev[:duration] = dleft / wodur.length
      ev
    end
    spread_days[k] = wdur + wodur
  end
  spread_days
end

days = spread_durations(days)

def billable_items(spread_durations)
  items = []
  current_items = {}
  prev_items = {}
  spread_durations.each do |day, events|
    events.each do |ev|
      billable = current_items[ev[:name]] || { amount: 0, st: day }
      billable[:amount] += ev[:duration]
      billable[:ed] = day
      current_items[ev[:name]] = billable
    end
    current_items, completed_items = current_items.partition do |_, billable|
      billable[:ed] == day
    end.map(&:to_h)
    items = items + completed_items.map { |k, v| [k, v] }
  end
  items
end

billables = billable_items(days)

def dates_to_string(st, ed)
  if st == ed
    st.strftime("%d/%m/%Y")
  else
    st.strftime("%d/%m/%y") + " - " + ed.strftime("%d/%m/%y")
  end
end

@vat_percent = 20
@daily_rate = 200
@billable_items = billables.map do |name, data|
  billable = {}
  billable[:description] = name
  billable[:date_string] = dates_to_string(data[:st], data[:ed])
  billable[:amount] = data[:amount]
  billable[:pre_tax_total] = @daily_rate * billable[:amount]
  billable[:vat] = @vat_percent / 100 * billable[:pre_tax_total]
  billable[:total] = billable[:pre_tax_total] + billable[:vat]
  billable
end

puts @billable_items

erb = ERB.new(File.read("./bill.erb"))

File.write("./result.html", erb.result(binding))

CSV.open('./output.csv', 'wb') do |csv|
  billables.each do |name, data|
    date_string = dates_to_string(data[:st], data[:ed])
    csv << [name, date_string, data[:amount]]
  end
end
