module ConsoleGif
  class PixelRun
    def self.for(pixels)
      prev = pixels.first
      pixels.slice_before { |crnt|
        slice, prev = (crnt != prev), crnt
        slice
      }.map { |slice| new slice }
    end

    attr_accessor :pixels
    def initialize(pixels)
      self.pixels = pixels
    end

    include Enumerable
    def each(&block)
      return to_enum :each unless block_given?
      pixels.each(&block)
    end

    def to_ansi
      "\e[#{ansi_color}m#{characters}\e[#{bg_off}m"
    end

    def ansi_color
      first.ansi_color
    end

    def bg_off
      first.bg_off
    end

    def characters
      pixels.map(&:characters).join
    end
  end
end
