require 'redis'
$redis = Redis.new

keys = $redis.keys('image.*.plate_number')
keys.each do |k|
  # p k
  p k.gsub( 'plate_number', '*' )
  p k.split( '.' )[0, 2].join('.')
#  v = $redis.get( )
end

