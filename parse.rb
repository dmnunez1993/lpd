require 'base64'
raw = File.read('x').chomp
raw = raw[22, raw.size]
image = Base64.decode64(raw)
open('test.png', 'w') do |f|
  f.print(image)
end
