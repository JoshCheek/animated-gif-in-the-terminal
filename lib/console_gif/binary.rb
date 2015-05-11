require 'console_gif'

module ConsoleGif
  module Binary
    HELP_SCREEN = <<-HELP_SCREEN.gsub /^ {6}/, ''
      Usage: ruby gif-to-ruby.rb [options]

      Synopsis:
        Emits Ruby code that will play an animated gif in the terminal

      Options:
        -h --help             # This help screen

        -s --style STYLE      # Set the output style (STYLE must be either "small", or "sharp")
                              # Default is "small"
                              #
                              # Small: Consolidates two rows of pixels into one character.
                              #        Advantage is that it is half as wide and half as tall, so fits better in the terminal.
                              #
                              # Sharp: Each pixel is two spaces with the background set.
                              #        Advantage is that it looks much better, as the 2-pixel representation
                              #        leaves a border around the top pixel.

        -o --output FILENAME  # Provide a file name to write the resulting Ruby program to.
                              # Stnadard output is the default
                              # A filename of "-" will explicitly set it to stdout.

        FILENAME              # A non-flag will be considered an input filename.
                              # It should be a valid gif file
                              # The default is Standard input
                              # A filename of "-" will explicitly set it to stdin

      Example output:
        $ curl -sL http://bit.ly/1DRCK7q | ruby -

      Example invocation:
        $ ruby gif-to-ruby.rb fixtures/owl.gif -s sharp -o - | ruby -
    HELP_SCREEN

    def self.call(argv, instream, outstream, errstream)
      parsed = parse argv, default_out: outstream, default_in: instream

      if parsed.fetch :print_help
        outstream.puts HELP_SCREEN
        return true
      end

      errors = parsed.fetch :errors
      if errors.any?
        errors.each { |error| errstream.puts error }
        return false
      end

      output_file = parsed.fetch :output_file
      input_file  = parsed.fetch :input_file
      gifdata     = (input_file.respond_to?(:read) ? input_file.read : File.read(input_file))
      print       = lambda { |stream| ConsoleGif::Animation.new(gifdata, parsed.fetch(:style)).to_rb(stream) }
      output_file.respond_to?(:write) ? print.call(output_file) : File.open(output_file, 'w', &print)
      return true
    rescue Errno::ENOENT => e
      errstream.puts e.message
      return false
    rescue Magick::ImageMagickError => e
      errstream.puts "Double check that input is a gif, ImageMagick raised this error:"
      errstream.puts e.message
      return false
    end

    def self.parse(args, defaults)
      args        = args.dup
      default_out = defaults.fetch :default_out
      default_in  = defaults.fetch :default_in
      parsed      = {
        errors:         [],
        filenames_seen: [],
        style:          :small,
        print_help:     false,
        output_file:    default_out,
        input_file:     default_in,
      }

      until args.empty?
        arg = args.shift
        case arg
        when '-s', '--style'
          style  = args.shift
          styles = ['sharp', 'small']
          if styles.include? style
            parsed[:style] = style.intern
          else
            parsed[:errors] << "Invalid style: #{style.inspect}"
          end
        when '-o', '--output'
          outfile = args.shift
          if outfile.nil?
            parsed[:errors] << "#{arg.inspect} expects an argument of the output filename"
          elsif outfile != '-'
            parsed[:output_file] = outfile
          end
        when '-h', '--help'
          parsed[:print_help] = true
        else
          parsed[:filenames_seen] << arg
          parsed[:input_file] = arg
          parsed[:input_file] = defaults[:default_in] if arg == '-'
        end
      end

      if 2 <= parsed[:filenames_seen].length
        parsed[:errors] << "Can only process one filename, but saw: #{parsed[:filenames_seen].map(&:inspect).join(', ')}"
      end

      parsed
    end
  end
end
