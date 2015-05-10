require 'zlib'
require 'rmagick'

    # kinda wish this was on Module
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


    attr_accessor :red, :green, :blue, :opaque

    def initialize(red:, green:, blue:, resolution:, opaque:)
      self.red    = convert red,   resolution
      self.green  = convert green, resolution
      self.blue   = convert blue,  resolution
      self.opaque = opaque
    end

    def to_ansi
      "\e[#{bg_ansi_colour}m  \e[#{bg_off}m"
    end

    def fg_ansi_colour
      opaque? ? "38;5;#{ansi_color}" : fg_off
    end

    def bg_ansi_colour
      opaque? ? "48;5;#{ansi_color}" : bg_off
    end

    alias opaque? opaque

    def ansi_color
      offset = 16 # I think these are for the system colors (30-37, 90-97)
      offset + (red   * resolution * resolution) +
               (green * resolution             ) +
               (blue                           )
    end
  end


  class CondensedPixel
    attr_accessor :top, :bottom

    def initialize(top_pixel, bottom_pixel)
      self.top, self.bottom = top_pixel, bottom_pixel
    end

    def to_ansi
      color_on  = "\e[#{top.fg_ansi_colour}#{bottom.bg_ansi_colour}m"
      color_off = "\e[#{top.fg_off        }#{bottom.bg_off        }m"
      "#{color_on}#{character}#{color_off}"
    end

    def character
      top.opaque? ? '▀' : ' '
    end
  end


  class Animation
    def initialize(gifdata, style)
      self.style, self.imagelist = style, Magick::ImageList.new.from_blob(gifdata).coalesce.remap
    end

    def frames
      @frames ||= begin
        frames = []
        imagelist.each { |frame|
          rows = []
          frame.each_pixel { |pixel, x, y|
            opaque = pixel.opacity < (0xFFFF * 0.05) # must be mostly opaque to qualify
            rows[y] ||= []
            rows[y][x] = Pixel.new red:      pixel.red,
                                   green:    pixel.green,
                                   blue:     pixel.blue,
                                   opaque:   opaque,
                                   resolution: 0xFFFF
          }
          frames << rows
        }
        frames
      end
    end

    def ansi_frames
      @ansi_frames ||= begin
        if style == :small
          self.frames.map do |rows|
            rows = [*rows, rows.last] if rows.length.odd?
            rows.each_slice(2).map do |slice|
              slice.transpose.map { |pair| CondensedPixel.new *pair }
            end
          end
        else
          raise 'wat'
        end
      end
    end

    def to_rb
  # rows << rows.first.map { Pixel.new 0, 0, 0, false } if rows.length.odd?
  # ansi_frame = rows.each_slice(2)
  #                  .map(&:transpose)
  #                  .join("\n")
  # ansi_frames << ansi_frame
# }

      compressed_frames = ansi_frames.map { |frame| Zlib::Deflate.deflate frame }
      clear             = "\e[H\e[2J".inspect
      hide_cursor       = "\e[?25l".inspect
      show_cursor       = "\e[?25h".inspect

      puts <<-PROGRAM.gsub
      require 'zlib'
      frames = [#{compressed_frames.map(&:inspect).join("\n")}]
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
    end

    private
    attr_accessor :style, :imagelist
  end
end


if $0 !~ /rspec/
else
  RSpec.describe ConsoleGif do
    def animation_for(fixture_filename, style: :small)
      fixture_filepath = File.join __dir__, 'fixtures', fixture_filename
      gifdata          = File.read(fixture_filepath)
      ConsoleGif::Animation.new(gifdata, style)
    end

    describe 'color conversion' do
      def assert_first_pixel(fixture_filename, assertions, style: :small)
        animation = animation_for fixture_filename, style: style
        frame     = animation.frames.first
        row       = frame.first
        assert_pixel row.first, assertions, "first pixel of #{fixture_filename.inspect}"
      end

      def assert_pixel(pixel, assertions, description)
        assertions.each do |channel, expected|
          actual = case channel
                   when :r      then pixel.red
                   when :g      then pixel.green
                   when :b      then pixel.blue
                   when :opaque then pixel.opaque?
                   else raise "Unknown channel: #{channel}"
                   end
          description += " should have #{channel} of #{expected.inspect}, but got #{actual.inspect}"
          expect(actual).to eq(expected), description
        end
      end

      it 'converts an r, g, or b value of 000-042 to console 0' do
        assert_first_pixel 'red000.gif',   r: 0, g: 0, b: 0
        assert_first_pixel 'red042.gif',   r: 0, g: 0, b: 0
        assert_first_pixel 'green000.gif', r: 0, g: 0, b: 0
        assert_first_pixel 'green042.gif', r: 0, g: 0, b: 0
        assert_first_pixel 'blue000.gif',  r: 0, g: 0, b: 0
        assert_first_pixel 'blue042.gif',  r: 0, g: 0, b: 0
      end

      it 'converts an r, g, or b value of 043-084 to console 1' do
        assert_first_pixel 'red043.gif',   r: 1, g: 0, b: 0
        assert_first_pixel 'red084.gif',   r: 1, g: 0, b: 0
        assert_first_pixel 'green043.gif', r: 0, g: 1, b: 0
        assert_first_pixel 'green084.gif', r: 0, g: 1, b: 0
        assert_first_pixel 'blue043.gif',  r: 0, g: 0, b: 1
        assert_first_pixel 'blue084.gif',  r: 0, g: 0, b: 1
      end

      it 'converts an r, g, or b value of 085-127 to console 2' do
        assert_first_pixel 'red085.gif',   r: 2, g: 0, b: 0
        assert_first_pixel 'red127.gif',   r: 2, g: 0, b: 0
        assert_first_pixel 'green085.gif', r: 0, g: 2, b: 0
        assert_first_pixel 'green127.gif', r: 0, g: 2, b: 0
        assert_first_pixel 'blue085.gif',  r: 0, g: 0, b: 2
        assert_first_pixel 'blue127.gif',  r: 0, g: 0, b: 2
      end

      it 'converts an r, g, or b value of 128-169 to console 3' do
        assert_first_pixel 'red128.gif',   r: 3, g: 0, b: 0
        assert_first_pixel 'red169.gif',   r: 3, g: 0, b: 0
        assert_first_pixel 'green128.gif', r: 0, g: 3, b: 0
        assert_first_pixel 'green169.gif', r: 0, g: 3, b: 0
        assert_first_pixel 'blue128.gif',  r: 0, g: 0, b: 3
        assert_first_pixel 'blue169.gif',  r: 0, g: 0, b: 3
      end

      it 'converts an r, g, or b value of 170-212 to console 4' do
        assert_first_pixel 'red170.gif',   r: 4, g: 0, b: 0
        assert_first_pixel 'red212.gif',   r: 4, g: 0, b: 0
        assert_first_pixel 'green170.gif', r: 0, g: 4, b: 0
        assert_first_pixel 'green212.gif', r: 0, g: 4, b: 0
        assert_first_pixel 'blue170.gif',  r: 0, g: 0, b: 4
        assert_first_pixel 'blue212.gif',  r: 0, g: 0, b: 4
      end

      it 'converts an r, g, or b value of 213-255 to console 5' do
        assert_first_pixel 'red213.gif',   r: 5, g: 0, b: 0
        assert_first_pixel 'red255.gif',   r: 5, g: 0, b: 0
        assert_first_pixel 'green213.gif', r: 0, g: 5, b: 0
        assert_first_pixel 'green255.gif', r: 0, g: 5, b: 0
        assert_first_pixel 'blue213.gif',  r: 0, g: 0, b: 5
        assert_first_pixel 'blue255.gif',  r: 0, g: 0, b: 5
      end

      it 'knows whether the pixel is tansparent or opaque' do
        pending 'not sure whether implementation or test is correct'
        # TODO: double check this is testing what we think it is
        assert_first_pixel 'opaque.gif',      opaque: true,  transparent: false
        assert_first_pixel 'transparent.gif', opaque: false, transparent: true
      end
    end

    it 'identifies and distinguishes each frame' do
      amt_red = animation_for('2x2x2.gif').frames.map { |fr| fr.map { |row| row.map &:red } }
      expect(amt_red).to eq [
        [[0, 1], [2, 3]], # frame1
        [[5, 4], [3, 2]], # frame 2
      ]
    end

    context 'when style is small' do
      let(:animation) { animation_for '4x4.gif', style: :small }
      let(:pixels)    { animation.ansi_frames[0].flatten }
      let(:pixel1)    { pixels.first }
      let(:tpixels)   { pixels.map &:top }
      let(:bpixels)   { pixels.map &:bottom }

      it 'groups each two rows of pixels together' do
        expect(tpixels.map &:red).to   eq [0, 0, 0, 0, 2, 2, 2, 2]
        expect(bpixels.map &:red).to   eq [1, 1, 1, 1, 3, 3, 3, 3]

        expect(tpixels.map &:green).to eq [0, 1, 2, 3, 0, 1, 2, 3]
        expect(bpixels.map &:green).to eq [0, 1, 2, 3, 0, 1, 2, 3]
      end

      it 'uses a square for the top row, and leaves the bottom row blank' do
        expect(pixels.first.character).to eq '▀'
      end

      it 'uses the top pixel\'s foreground colour and the bottom pixel\'s background colour' do
        expect(pixel1.to_ansi).to     include pixel1.top.fg_ansi_colour
        expect(pixel1.to_ansi).to_not include pixel1.bottom.fg_ansi_colour

        expect(pixel1.to_ansi).to     include pixel1.bottom.bg_ansi_colour
        expect(pixel1.to_ansi).to_not include pixel1.top.bg_ansi_colour
      end

      it 'reuses the last row, if it is not even' do
        pixel = animation_for('red000.gif').ansi_frames[0][0][0]
        expect(pixel.top).to equal pixel.bottom
      end
    end

    context 'when style is sharp' do
      it 'does not group pixels together'
      it 'uses 2 spaces for the pixel'
      it 'uses the pixel\'s background colour'
    end

    context 'integration' do
      example 'small image'
      example 'sharp image'
      example 'animated image has a delay between frames'
    end
  end
end
