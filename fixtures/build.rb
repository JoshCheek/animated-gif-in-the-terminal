Dir.chdir __dir__

# translation of an example I found at http://www.imagemagick.org/discourse-server/viewtopic.php?t=20055
def build(filename, pixels)
  rows       = pixels.kind_of?(Array) ? pixels : [pixels]
  rows       = rows.map { |row| row.kind_of?(Array) ? row : [row] }
  dimensions = "#{rows.length}x#{rows.first.length}"
  pixel_args = rows.flat_map.with_index do |row, y|
    row.flat_map.with_index do |pixel, x|
      channels = [pixel.fetch(:red), pixel.fetch(:green), pixel.fetch(:blue), pixel.fetch(:alpha, 1)]
      ["-fill", "RGBA(#{channels.join ','})", '-draw', "point #{y},#{x}"]
    end
  end

  if File.exist? filename
    puts "skipping #{filename}"
  else
    program = 'convert', '-size', dimensions, "xc:none", *pixel_args, filename
    system *program
    puts program.join ' ' if $?.success?
  end
end


# each of red, green, blue
[0, 42, 43, 84, 85, 127, 128, 169, 170, 212, 213, 255].each do |n|
  build "red#{   n.to_s.rjust 3, '0'}.gif", red: n, green: 0, blue: 0
  build "green#{ n.to_s.rjust 3, '0'}.gif", red: 0, green: n, blue: 0
  build "blue#{  n.to_s.rjust 3, '0'}.gif", red: 0, green: 0, blue: n
end

# black/white, transparent/opaque
build "transparent.gif", red: 0, green: 0, blue: 0, alpha: 1
build "opaque.gif",      red: 0, green: 0, blue: 0, alpha: 0

# 8x8
build '8x8.gif', 8.times.map { |y|
  8.times.map { |x| {red: 4, green: x, blue: x+y} }
}

# 2x2 for 2 frames
