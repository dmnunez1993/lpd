Dir['model/*'].each do |f|
  File.delete(f)
end

require 'redis'

r = Redis.new
r.keys('image*').each do |k|
  r.del(k)
end

