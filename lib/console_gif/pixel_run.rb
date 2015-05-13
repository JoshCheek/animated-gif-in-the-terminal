module ConsoleGif
  class BackgroundPixelRun
    attr_accessor :length
    def initialize(length)
      self.length = length
    end

    def ==(other)
      length == other.length
    end

    def to_ansi
      "\e[#{length}C"
    end

    def ansi_color
      raise "uhm, this polymorphism is questionable :/"
    end


    def characters
      ""
    end

    def ansi_color_off
      ""
    end

    def pixels
      [self]
    end
  end

  class SkipLines
    attr_accessor :num
    def initialize(n)
      self.num = n
    end

    def ==(other)
      num == other.num
    end

    def to_ansi
      "\e[#{num}B"
    end

    def pixels
      self
    end
  end


  class PixelRun
    def self.run_length_bg(i, fg, bg)
      initial = i
      i += 1 while i < fg.length && fg[i] == bg[i]
      i - initial
    end

    def self.run_length_fg(start_index, fg)
      index      = start_index
      prev_index = start_index
      while fg[index] && fg[prev_index] == fg[index]
        prev_index, index = index, index.succ
      end
      index - start_index
    end

    def self.for_frames(frames)
      all = [self.for_frame(frames[0])]
      frames.each_cons 2 do |bgrows, fgrows|
        rows = bgrows.zip(fgrows).map { |bgrow, fgrow|
          row, i = [], 0
          while i < fgrow.length
            fgdist = run_length_fg(i, fgrow)
            bgdist = run_length_bg(i, fgrow, bgrow)
            if bgdist < fgdist
              row << PixelRun.new(fgrow[i, fgdist])
              i += fgdist
            else
              row << BackgroundPixelRun.new(bgdist)
              i += bgdist
            end
          end
          row
        }

        consolidated_rows = []
        until rows.empty?
          skippable_rows = rows.take_while do |row|
            row.length == 1 && row.first.kind_of?(BackgroundPixelRun)
          end
          if skippable_rows.any?
            rows = rows.drop(skippable_rows.length)
            consolidated_rows << [SkipLines.new(skippable_rows.length)]
          else
            consolidated_rows << rows.shift
          end
        end

        all << consolidated_rows
      end
      all
    end

    def self.for_frame(frame)
      frame.map { |row| for_row row }
    end

    def self.for_row(row)
      prev = row.first
      row.slice_before { |crnt|
        slice, prev = (crnt != prev), crnt
        slice
      }.map { |pixels| new pixels }
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
      "\e[#{ansi_color}m#{characters}\e[#{ansi_color_off}m"
    end

    def ansi_color
      first.ansi_color
    end

    def ansi_color_off
      first.ansi_color_off
    end

    def characters
      pixels.map(&:characters).join
    end
  end
end
