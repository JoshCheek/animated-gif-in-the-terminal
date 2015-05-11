require 'zlib'
require 'rmagick'
require 'console_gif/pixel'
require 'console_gif/condensed_pixel'

module ConsoleGif
  class Animation
    def initialize(gifdata, style)
      self.style, self.imagelist = style, Magick::ImageList.new.from_blob(gifdata).coalesce.remap
    end

    def frames
      @frames ||= imagelist.to_enum(:each).map do |image| # apparently they overrode #map to do wonky ass shit
        image.to_enum(:each_pixel).with_object([]) do |(pixel, x, y), rows|
          rows[y]  ||= Array.new
          rows[y][x] = Pixel.new red:        pixel.red,
                                 green:      pixel.green,
                                 blue:       pixel.blue,
                                 opaque:     pixel.opacity.zero?, # seems fkn backwards -.^
                                 resolution: 0xFFFF
        end
      end
    end

    def ansi_frames
      @ansi_frames ||= begin
        case style
        when :sharp
          frames
        when :small
          self.frames.map do |rows|
            rows = [*rows, rows.last] if rows.length.odd?
            rows.each_slice(2).map do |slice|
              slice.transpose.map { |pair| CondensedPixel.new *pair }
            end
          end
        else
          raise "Unknown style: #{style.inspect}"
        end
      end
    end

    def to_rb(outfile='')
      compressed_frames = ansi_frames.map { |rows|
        frame = rows.map { |pixels| pixels.map &:to_ansi }
                    .map(&:join)
                    .join("\n")
        Zlib::Deflate.deflate(frame)
      }

      clear       = "\e[H\e[2J".inspect
      hide_cursor = "\e[?25l".inspect
      show_cursor = "\e[?25h".inspect
      outfile << <<-PROGRAM.gsub(/^ {8}/, '')
        require 'zlib'
        frames = [#{compressed_frames.map(&:inspect).join(",\n  ")}
        ]
        begin
          print #{clear}#{hide_cursor}
          frames.each.with_index 1 do |frame, nxt|
            print Zlib::Inflate.inflate frame
            sleep 0.1
            print #{clear} if frames[nxt]
          end
          puts
        ensure
          print #{show_cursor}
        end
      PROGRAM
    end

    private
    attr_accessor :style, :imagelist
  end
end
