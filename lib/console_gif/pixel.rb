module ConsoleGif
  class Pixel
    [ def convert(original_color, original_resolution)
        new_value = resolution * original_color / original_resolution.to_f
        new_value = new_value.to_i
        new_value = resolution - 1 if resolution <= new_value
        new_value
      end,

      def resolution
        6 # each of r, g, and b have 6 possible values
      end,

      def fg_off
        "39"
      end,

      def bg_off
        "49"
      end,
    ].each do |name|
      definition = instance_method(name).bind(allocate)
      define_singleton_method name, &definition
    end


    attr_accessor :red, :green, :blue

    def initialize(red:, green:, blue:, resolution:, opaque:)
      self.red    = convert red,   resolution
      self.green  = convert green, resolution
      self.blue   = convert blue,  resolution
      @opaque     = opaque
    end

    def to_ansi
      "\e[#{bg_ansi_colour}m#{character}\e[#{bg_off}m"
    end

    def fg_ansi_colour
      opaque? ? "38;5;#{ansi_color}" : fg_off
    end

    def bg_ansi_colour
      opaque? ? "48;5;#{ansi_color}" : bg_off
    end

    def opaque?
      @opaque
    end

    def transparent?
      !opaque?
    end

    def character
      '  '
    end

    def ansi_color
      offset = 16 # I think these are for the system colors (30-37, 90-97)
      offset + (red   * resolution * resolution) +
               (green * resolution             ) +
               (blue                           )
    end
  end
end
