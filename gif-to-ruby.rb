require 'zlib'

class ConsolePixel
  attr_accessor :red, :green, :blue, :opaque

  def initialize(red, green, blue, opaque)
    self.red, self.green, self.blue, self.opaque = red, green, blue, opaque
  end

  def to_s(is_fg)
    if    opaque? && is_fg then "38;5;#{ansi_color}" # set fg
    elsif opaque?          then "48;5;#{ansi_color}" # set bg
    elsif is_fg            then "39"                 # fg off
    else                        "49"                 # bg off
    end
  end

  def opaque?
    opaque
  end

  private

  def ansi_color
    n   = 6            # each of r, g, and b have 6 possible values
    max = 0xFFFF.to_f  # colors stored in 16 bits
    r   = (n * red   / max).to_i
    g   = (n * green / max).to_i
    b   = (n * blue  / max).to_i
    16 + r*n*n + g*n + b # move them to their offsets, I think the first 16 are for the system colors
  end
end


require 'rmagick'

ansi_frames = []

Magick::ImageList
  .new
  .from_blob($stdin.read)
  .coalesce
  .remap
  .each { |frame|
    rows = []
    frame.each_pixel { |pixel, x, y|
      opaque = pixel.opacity < (0xFFFF * 0.05) # must be mostly opaque to qualify
      rows[y] ||= []
      rows[y][x] = ConsolePixel.new pixel.red, pixel.green, pixel.blue, opaque
    }
    ansi_frame = rows.each_slice(2)
                     .map(&:transpose)
                     .map { |pairs|
                       pairs.map { |top, bottom| "\e[#{top.to_s true};#{bottom.to_s false}m#{top.opaque? ? '▀' : ' '}\e[0m" }.join
                     }
                     .join("\n")
    ansi_frames << ansi_frame
  }

compressed_frames = ansi_frames.map { |frame| Zlib::Deflate.deflate frame }
clear             = "\e[H\e[2J".inspect
hide_cursor       = "\e[?25l".inspect
show_cursor       = "\e[?25h".inspect

puts <<PROGRAM
require 'zlib'
frames = #{compressed_frames.inspect}
begin
  print #{clear}#{hide_cursor}
  frames.each.with_index 1 do |frame, nxt|
    print Zlib::Inflate.inflate frame
    sleep 0.1
    print #{clear} if frames[nxt]
  end
ensure
  print #{show_cursor}
end
PROGRAM
