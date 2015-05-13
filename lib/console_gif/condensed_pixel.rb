module ConsoleGif
  class CondensedPixel
    attr_accessor :top, :bottom

    def initialize(top_pixel, bottom_pixel)
      self.top, self.bottom = top_pixel, bottom_pixel
    end

    def to_ansi
      "\e[#{ansi_color}m#{characters}\e[#{ansi_color_off}m"
    end

    def ansi_color
      "#{top.fg_ansi_colour};#{bottom.bg_ansi_colour}"
    end

    def ansi_color_off
      "#{top.ansi_color_off};#{bottom.ansi_color_off}"
    end

    def characters
      top.opaque? ? '▀' : ' '
    end

    def ==(condensed_pixel)
      top == condensed_pixel.top && bottom == condensed_pixel.bottom
    end
  end
end
