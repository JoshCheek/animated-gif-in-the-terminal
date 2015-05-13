require 'zlib'
require 'rmagick'
require 'console_gif/pixel'
require 'console_gif/condensed_pixel'
require 'console_gif/pixel_run'

module ConsoleGif
  class Animation
    def self.frames_for(list)
      list.to_enum(:each).map do |image| # apparently they overrode #map to do wonky ass shit
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


    def self.ansi_frames_for(frames, style)
      return frames                           if style == :sharp
      raise "Unknown style: #{style.inspect}" if style != :small

      frames.map do |rows|
        rows = [*rows, rows.last] if rows.length.odd?
        rows.each_slice(2).map do |slice|
          slice.transpose.map { |pair| CondensedPixel.new *pair }
        end
      end
    end


    attr_accessor :style, :imagelist, :frames, :ansi_frames, :pixel_runs
    def initialize(gifdata, style)
      self.style       = style
      self.imagelist   = Magick::ImageList.new.from_blob(gifdata).coalesce.remap
      self.frames      = Animation.frames_for imagelist
      self.ansi_frames = Animation.ansi_frames_for frames, style
      self.pixel_runs  = PixelRun.for_frames ansi_frames
    end

    def to_rb(outfile='')
      compressed_frames = pixel_runs.map { |rows|
        frame = rows.map { |pixels| pixels.map &:to_ansi }
                    .map(&:join)
                    .join("\n")
        Zlib::Deflate.deflate(frame)
      }

      topleft     = "\e[H".inspect
      clear       = "\e[H\e[2J".inspect
      hide_cursor = "\e[?25l".inspect
      show_cursor = "\e[?25h".inspect
      outfile << <<-PROGRAM.gsub(/^ {8}/, '')
        require 'zlib'
        frames = [#{compressed_frames.map(&:inspect).join(",\n  ")}
        ].map { |frame| Zlib::Inflate.inflate frame }
        begin
          print #{clear}#{hide_cursor}
          frames.each.with_index 1 do |frame, nxt|
            print frame
            sleep 0.1
            print #{topleft} if frames[nxt]
          end
          puts
        ensure
          print #{show_cursor}
        end
      PROGRAM
    end
  end
end
