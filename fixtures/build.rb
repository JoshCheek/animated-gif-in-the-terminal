Dir.chdir __dir__

def depth(obj)
  return 0 unless obj.kind_of? Array
  child_depths = obj.map { |child| depth child }
  raise "Inconsistent child depths: #{child_depths}" if 1 < child_depths.uniq.length
  (child_depths.first || 0).next
end

def normalize_depth(obj, to:)
  diff = to - depth(obj)
  obj, diff = [obj], diff-1 while 0 < diff
  obj
end

# translation of an example I found at http://www.imagemagick.org/discourse-server/viewtopic.php?t=20055
def build(filename, frames)
  frames     = normalize_depth frames, to: 3 # frames are rows of pixels
  pixel_args = frames.flat_map.with_index do |rows, z|
    width, height = frames.first.first.length, frames.first.length
    [ '(',
      '-size', "#{width}x#{height}", 'xc:none',
      '-frame', z.to_s,
      *rows.flat_map.with_index { |pixels, y|
        pixels.flat_map.with_index do |pixel, x|
          color = if pixel[:transparent]
            ['-alpha', 'Transparent']
          else
            ["-fill", "RGB(#{pixel.fetch :red},#{pixel.fetch :green},#{pixel.fetch :blue})",
             "-draw", "point #{x},#{y}"
            ]
          end
        end
      },
      ')',
    ]
  end

  if File.exist? filename
    puts "skipping #{filename}"
  else
    program = 'convert', '-coalesce', *pixel_args, filename
    puts program.join ' '
    system *program
  end
end


# each of red, green, blue
[0, 42, 43, 84, 85, 127, 128, 169, 170, 212, 213, 255].each do |n|
  build "red#{   n.to_s.rjust 3, '0'}.gif", red: n, green: 0, blue: 0
  build "green#{ n.to_s.rjust 3, '0'}.gif", red: 0, green: n, blue: 0
  build "blue#{  n.to_s.rjust 3, '0'}.gif", red: 0, green: 0, blue: n
end

# transparent/opaque
build "transparent.gif", transparent: true
build "opaque.gif",      red: 0, green: 0, blue: 0

# 8x8
build '4x4.gif', 4.times.map { |y|
  4.times.map { |x| {red: y*43, green: x*43, blue: 0} }
}

# 2x2 for 2 frames
build '2x2x2.gif', [
  [ [{red: 0,  green: 0,  blue: 0},  {red: 50,  green: 50,  blue: 50}],  # console 0, 1
    [{red: 90, green: 90, blue: 90}, {red: 130, green: 130, blue: 130}], # console 2, 3
  ],
  [ [{red: 255, green: 255, blue: 255}, {red: 210, green: 210, blue: 210}], # console 5, 4
    [{red: 160, green: 160, blue: 160}, {red: 120, green: 120, blue: 120}], # console 3, 2
  ],
]
