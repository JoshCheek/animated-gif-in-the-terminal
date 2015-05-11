module ConsoleGif
  class CondensedPixel
    attr_accessor :top, :bottom

    def initialize(top_pixel, bottom_pixel)
      self.top, self.bottom = top_pixel, bottom_pixel
    end

    def to_ansi
      color_on  = "\e[#{top.fg_ansi_colour};#{bottom.bg_ansi_colour}m"
      color_off = "\e[#{top.fg_off        };#{bottom.bg_off        }m"
      "#{color_on}#{character}#{color_off}"
    end

    def character
      top.opaque? ? '▀' : ' '
    end
  end
end
