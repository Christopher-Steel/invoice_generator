class DurationSpreader
  GRAIN = 8.0

  def self.GRAIN
    GRAIN
  end

  def self.granulate(f)
    (f * GRAIN).round / GRAIN
  end

  def self.spread_total(spread)
    spread.reduce(:+)
  end

  def self.validate_spread(dividend, spread)
    @i = (@i || 0) + 1
    total = spread.reduce(:+)
    spread.all? { |part| granulate(part) == part }
  end

  def self.spread_duration(duration, spread_size)
    @i = 0
    guess = duration / spread_size
    validate_spread(duration, [guess] * spread_size)
    guess = granulate(guess)
    spread = [guess] * spread_size
    validate_spread(duration, spread)
    total = spread_total(spread)
    if total != duration
      spread[0] += duration - total
    end
    validate_spread(duration, spread)
    spread
  end
end
