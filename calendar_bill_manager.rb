require 'icalendar'

class CalendarBillManager
  def initialize(calendar_path)
    cal_file = File.open(calendar_path)
    @cal = Icalendar::Calendar.parse(cal_file).first
  end

  def extract_unbilled_events
    return [@cal.events, nil, nil]
  end

  def extract_timespan_events(first_day, last_day)
    accepted = []
    rejected = []
    @cal.events.each do |ev|
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

  def extract_events
    f_day = Date.parse("2017-11-27T:00:00:00+00:00Z")
    l_day = Date.parse("2017-12-31T:00:00:00+00:00Z")

    return [extract_timespan_events(f_day, l_day), f_day, l_day]
  end
end
