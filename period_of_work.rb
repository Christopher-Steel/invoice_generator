require "pp"

class PeriodOfWork
  def initialize(start_day, end_day, days = {})
    @f_day = start_day
    @l_day = end_day
    @days = days
    (@f_day..@l_day).each { |d| days[d] = [] } unless @days.length > 0
  end

  def begin
    @f_day
  end

  def end
    @l_day
  end

  def add_events(events)
    events.each { |ev| spread_event_across_days(ev) }
  end

  def spread_durations
    spread_days = {}
    @days.each do |k, d|
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
        STDERR.puts "Warning: More than one day's worth of events on day #{k}" if dleft < 0
      end
      spread_days[k] = wdur
      unless wodur.length == 0
        comms, wodur = wodur.partition { |ev| ev[:name].start_with?("(comms)") }
        comms.each do |ev|
          dur = 1 / DurationSpreader.GRAIN
          ev[:duration] = dur
          dleft -= dur
        end
        durations = DurationSpreader.spread_duration(dleft, wodur.length)
        wodur.each do |ev|
          ev[:duration] = durations.shift || 30000.0 # stupidly high value so that I notice it's gone wrong
        end
        spread_days[k] += comms + wodur
      end
    end
    @days = spread_days
  end

  def split_by_month
    puts "ALL DAYS:"
    pp @days
    bom = @f_day
    eom = Date.new(bom.year, bom.month, -1)
    spans = []
    while eom < @l_day
      spans << (bom..eom)
      bom = eom + 1
      eom = Date.new(bom.year, bom.month, -1)
    end
    spans << (bom..@l_day)
    spans.map do |sp|
      span_days = @days.select { |key, _| key >= sp.begin && key <= sp.end }
      puts "\nspan #{sp} days:"
      pp span_days
      PeriodOfWork.new(sp.begin, sp.end, span_days)
    end
  end

  def to_billable_items
    items = []
    current_items = {}
    prev_items = {}
    @days.each do |day, events|
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
    items + current_items.map { |k, v| [k, v] }
  end

  def spread_event_across_days(ev)
    timespan = event_timespan(ev)
    duration = event_duration_from_summary(ev)
    # TODO handle edge case of a durationed event being spread across several days
    # it shouldn't split to even units if doing so creates non 8th portions
    duration /= timespan.count unless duration.nil?
    timespan.each do |d|
      @days[d] << { name: event_name_from_summary(ev), duration: duration }
    end
    @days
  end

  def event_timespan(ev)
    st, ed = [ev.dtstart, ev.dtend].map { |d| d.value.to_date unless d.nil? }
    (st...ed)
  end

  def event_duration_from_summary(ev)
    return $1.to_f if /^(\d+(\.\d+)?).*$/ =~ ev.summary
    nil
  end

  def event_name_from_summary(ev)
    return $2 if /^\d+(\.\d+)?\s*(.*)$/ =~ ev.summary
    ev.summary
  end
end
