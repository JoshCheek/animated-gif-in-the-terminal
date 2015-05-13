require 'console_gif/binary'

RSpec.describe ConsoleGif do
  def fixture_path(basename)
    File.join __dir__, '..', 'fixtures', basename
  end

  def animation_for(fixture_filename, style: :small)
    fixture_filepath = fixture_path fixture_filename
    gifdata          = File.read(fixture_filepath)
    ConsoleGif::Animation.new(gifdata, style)
  end

  describe 'Binary' do
    def parse(args, defaults={})
      defaults[:default_out] ||= :default_out
      defaults[:default_in]  ||= :default_in
      expect(defaults.length).to eq 2
      ConsoleGif::Binary.parse(args, defaults)
    end

    context 'commandline arguments' do
      it 'doesn\'t mutate the args it parses' do
        args = ['-s', 'sharp', '-o', 'out', 'in', '-h']
        parse args
        expect(args).to eq ['-s', 'sharp', '-o', 'out', 'in', '-h']
      end

      describe 'style' do
        it 'can be given a style with -s and --style' do
          expect(parse(['-s',      'sharp'])[:style]).to eq :sharp
          expect(parse(['--style', 'sharp'])[:style]).to eq :sharp
        end

        it 'accepts values of small and sharp' do
          expect(parse(['-s', 'small'])[:style]).to eq :small
          expect(parse(['-s', 'sharp'])[:style]).to eq :sharp
        end

        it 'sets an error if the style is unknown' do
          expect(parse(['-s', 'small'])[:errors]).to be_empty
          expect(parse(['-s', 'wat'])[:errors]).to_not be_empty
        end

        it 'defaults to small' do
          expect(parse([])[:style]).to eq :small
        end
      end

      describe 'output_file' do
        it 'can be given an output file with -o and --output' do
          expect(parse(['-o', 'fn'],       default_out: :stdout)[:output_file]).to eq 'fn'
          expect(parse(['--output', 'fn'], default_out: :stdout)[:output_file]).to eq 'fn'
        end

        it 'defaults to stdout' do
          expect(parse([], default_out: :stdout)[:output_file]).to eq :stdout
        end

        specify 'output file of "-" means stdout' do
          expect(parse(['-o', '-'], default_out: :stdout)[:output_file]).to eq :stdout
        end

        it 'sets an error if the output file is not provided' do
          expect(parse(['-o', 'fn'], default_out: :stdout)[:errors]).to be_empty
          expect(parse(['-o'],       default_out: :stdout)[:errors]).to_not be_empty
        end
      end

      describe 'input_file' do
        it 'is the first non-flag/arg' do
          expect(parse(['infile'], default_in: :stdin)[:input_file]).to eq 'infile'
        end

        it 'sets an error if given multiple input files' do
          expect(parse(['f1'],                        default_in: :stdin)[:errors]).to be_empty
          expect(parse(['f1'],                        default_in: :stdin)[:errors]).to be_empty
          expect(parse(['f1', 'f2'],                  default_in: :stdin)[:errors]).to_not be_empty
          expect(parse(['a', '-'],                    default_in: :stdin)[:errors]).to_not be_empty
          expect(parse(['-', 'a'],                    default_in: :stdin)[:errors]).to_not be_empty
          expect(parse(['f1', 'f2', '-o', '-', 'f3'], default_in: :stdin)[:filenames_seen])
                .to eq ['f1', 'f2',            'f3']
        end

        specify 'input file of "-" means stdin' do
          expect(parse(['-'], default_in: :stdin)[:input_file]).to eq :stdin
          expect(parse(['-'], default_in: :stdin)[:errors]).to be_empty
        end

        it 'defaults to "-" if the input file is not provided' do
          expect(parse([], default_in: :stdin)[:input_file]).to eq :stdin
        end
      end

      describe 'print_help' do
        it 'can be told to print help with "-h" and "--help"' do
          expect(parse([])[:print_help]).to eq false
          expect(parse(['-h'])[:print_help]).to eq true
          expect(parse(['--help'])[:print_help]).to eq true
        end
      end
    end

    describe '.call' do
      require 'stringio'
      def call(argv, instream:StringIO.new, outstream:StringIO.new, errstream:StringIO.new)
        ConsoleGif::Binary.call argv, instream, outstream, errstream
      end

      require 'tempfile'
      def with_tmpfile(&block)
        Tempfile.open 'animated-gif-terminal' do |file|
          yield file
          File.read file.path
        end
      end

      context 'when there are no errors' do
        it 'parses the args, reads the data, writes the ruby, and returns true' do
          instream, outstream, errstream = StringIO.new('original-instream'), StringIO.new, StringIO.new
          success = call ['-s', 'sharp', fixture_path('red000.gif'), '-o', '-'], instream: instream, outstream: outstream, errstream: errstream
          expect(instream.read).to eq 'original-instream' # was not read
          expect(errstream.string).to be_empty
          expect(outstream.string).to eq animation_for('red000.gif', style: :sharp).to_rb
          expect(success).to eq true
        end

        it 'can write to outstream or a file' do
          outstream = StringIO.new
          call [fixture_path('red000.gif'), '-o', '-'], outstream: outstream
          printed = outstream.string
          expect(outstream.string).to_not be_empty

          filebody = with_tmpfile do |file|
            outstream = StringIO.new
            call [fixture_path('red000.gif'), '-o', file.path], outstream: outstream
            expect(outstream.string).to be_empty
          end

          expect(filebody).to eq printed # same thing winds up in both
        end

        it 'can read from instream or a file' do
          gifdata    = File.read fixture_path 'red000.gif'
          outstream1 = StringIO.new
          outstream2 = StringIO.new
          instream1  = StringIO.new gifdata
          instream2  = StringIO.new gifdata

          call ['-', '-o', '-'], instream: instream1, outstream: outstream1
          expect(instream1.read).to be_empty

          call [fixture_path('red000.gif'), '-o', '-'], instream: instream2, outstream: outstream2
          expect(instream2.read).to eq gifdata

          expect(outstream1.string).to eq outstream2.string
        end
      end

      context 'when there is an error' do
        it 'prints errors to the error stream' do
          multiple_infile_err = parse(['a', 'b'])[:errors].fetch(0)
          errstream           = StringIO.new
          call ['a', 'b'], errstream: errstream
          expect(errstream.string.chomp).to eq multiple_infile_err
        end

        it 'returns false' do
          expect(call ['a', 'b']).to eq false
        end
      end

      it 'prints an error when the input file DNE' do
        errstream = StringIO.new
        expect(call ['not/a/file'], errstream: errstream).to eq false
        expect(errstream.string).to include 'not/a/file'
      end

      it 'prints an error when the output file DNE' do
        errstream = StringIO.new
        expect(call ['-o', 'not/a/file'], errstream: errstream).to eq false
        expect(errstream.string).to include 'not/a/file'
      end

      it 'prints an error when the input file isn\'t a gif' do
        instream  = StringIO.new 'random giberish'
        errstream = StringIO.new
        expect(call ['-', '-o', '-'], instream: instream, errstream: errstream).to eq false
        expect(errstream.string).to match /input is a gif/i
      end

      it 'prints help when told to' do
        outstream = StringIO.new
        expect(call ['-h'], outstream: outstream).to eq true
        expect(outstream.string).to match /usage/i
      end
    end
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
                 when :r           then pixel.red
                 when :g           then pixel.green
                 when :b           then pixel.blue
                 when :opaque      then pixel.opaque?
                 when :transparent then pixel.transparent?
                 else raise "Unknown channel: #{channel}"
                 end
        expect(actual).to eq(expected), "#{description} should have #{channel} of #{expected.inspect}, but got #{actual.inspect}"
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
      expect(pixels.first.characters).to eq '▀'
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
    let(:animation) { animation_for '4x4.gif', style: :sharp }
    let(:pixels)    { animation.ansi_frames[0].flatten }
    let(:pixel1)    { pixels.first }

    it 'does not group pixels together' do
      expect(pixels.map &:red).to eq [
        0, 0, 0, 0,
        1, 1, 1, 1,
        2, 2, 2, 2,
        3, 3, 3, 3,
      ]
      expect(pixels.map &:green).to eq [
        0, 1, 2, 3,
        0, 1, 2, 3,
        0, 1, 2, 3,
        0, 1, 2, 3,
      ]
    end

    it 'uses 2 spaces for the pixel' do
      expect(pixel1.characters).to eq '  '
    end

    it 'uses the pixel\'s background colour' do
      expect(pixel1.to_ansi).to     include pixel1.bg_ansi_colour
      expect(pixel1.to_ansi).to_not include pixel1.fg_ansi_colour
    end
  end


  context 'pixel runs' do
    def row_runs(row_hashes)
      pixels = row_hashes.map do |hash|
        hash[:opaque] = true
        hash[:resolution] ||= ConsoleGif::Pixel.resolution
        ConsoleGif::Pixel.new hash
      end
      ConsoleGif::PixelRun.for_row pixels
    end

    it 'consolidates pixels that are equal into a run' do
      runs = row_runs [
        {red:0, green:0, blue:0},
        {red:0, green:0, blue:0},
        {red:0, green:1, blue:0},
        {red:0, green:0, blue:1},
        {red:2, green:0, blue:0},
        {red:2, green:0, blue:0},
      ]

      reds = runs.map { |run| run.map &:red }
      expect(reds).to eq [[0, 0], [0], [0], [2, 2]]

      reds = runs.map { |run| run.map &:green }
      expect(reds).to eq [[0, 0], [1], [0], [0, 0]]

      reds = runs.map { |run| run.map &:blue }
      expect(reds).to eq [[0, 0], [0], [1], [0, 0]]
    end

    it 'has the same ansi code as the pixels it wraps, but with each one\'s character' do
      run = row_runs([
        {red:2, green:0, blue:0},
        {red:2, green:0, blue:0},
      ]).first
      pixel = run.first
      expect(run.to_ansi).to eq "\e[#{pixel.bg_ansi_colour}m#{pixel.characters * 2}\e[#{pixel.bg_off}m"
    end

    class FakePixel
      attr_accessor :name
      def initialize(name)
        self.name = name
      end

      def inspect
        "#<FakePixel #{name.inspect}>"
      end

      def ==(other)
        name == other.name
      end
    end

    def bg(n)
      ConsoleGif::BackgroundPixelRun.new(n)
    end

    def down(n)
      ConsoleGif::SkipLines.new(n)
    end

    def frame_runs(frames)
      ConsoleGif::PixelRun.for_frames(frames)
    end

    it 'chooses the background colour when runs of background colour are longer' do
      r, g, b = FakePixel.new(:red), FakePixel.new(:green), FakePixel.new(:blue)
      frame1 = [[r, g, g, g]]
      frame2 = [[r, r, g, g]] # chooses pixels, bg
      frame3 = [[r, r, g, r]] # chooses bg, pixels
      frames = frame_runs [frame1, frame2, frame3]
      expect(frames.length).to eq 3
      expect(frames[0].first.map(&:pixels)).to eq [[r], [g, g, g]]
      expect(frames[1].first.map(&:pixels)).to eq [[r, r], [bg(2)]]
      expect(frames[2].first.map(&:pixels)).to eq [[bg(3)], [r]]
    end

    it 'swaps rows that are entirely background with a command to move the cursor down', t:true do
      r, g, b = FakePixel.new(:red), FakePixel.new(:green), FakePixel.new(:blue)
      frame = [[r,r,r], [g,g,g]]
      frames = frame_runs [frame, frame, frame]
      expect(frames.length).to eq 3
      expect(frames[0].map { |rows| rows.map(&:pixels) }).to eq [[[r, r, r]], [[g, g, g]]]
      expect(frames[1].map { |rows| rows.map(&:pixels) }).to eq [[down(2)]]
      expect(frames[2].map { |rows| rows.map(&:pixels) }).to eq [[down(2)]]
    end
  end


  context 'integration', integration: true do
    example 'small image' do
      expect(animation_for('owl.gif', style: :small).to_rb)
        .to eq File.read(fixture_path 'owl-small.rb')
    end

    example 'sharp image' do
      expect(animation_for('owl.gif', style: :sharp).to_rb)
        .to eq File.read(fixture_path 'owl-sharp.rb')
    end

    # could hijack the env and load this code, but don't care that much right now
    specify 'animated image has a 0.1s delay between frames'
    it 'hides the cursor at the beginning and shows it at the end'
    it 'ensures the cursor is re-shown, even if errors get raised'
  end
end
