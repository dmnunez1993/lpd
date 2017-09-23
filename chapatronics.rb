require 'sinatra'
require 'base64'
require 'redis'
require 'json'
require 'tempfile'
require 'yaml'

$redis = Redis.new()

MODEL_PATH = 'model'

class Image
  attr_reader :image_path, :plate_number, :id, :name
  def initialize( image_path, plate_number, name, create_new=true, id=0 )
    if create_new
      @id, @image_path, @plate_number, @name = $redis.incr('image'), image_path, plate_number, name
      $redis.set( "image.#{@id}", "" )
      $redis.set( "image.#{@id}.image_path", @image_path )
      $redis.set( "image.#{@id}.plate_number", @plate_number )
      $redis.set( "image.#{@id}.name", @name )
    else
      @id, @image_path, @plate_number, @name = id, image_path, plate_number, name
    end
  end
  def self.find_by_id(id)
    image_path = $redis.get("image.#{id}.image_path" )
    plate_number = $redis.get("image.#{id}.plate_number" )
    name = $redis.get("image.#{id}.name" )
    return Image.new( image_path, plate_number, name, false, id )
  end
  def self.all()
    images = []
    $redis.keys('image.*').each do |base_key|
      splits = base_key.split('.')
      if splits.size == 2
        id = splits[1]
        image_path = $redis.get("image.#{id}.image_path" )
        plate_number = $redis.get("image.#{id}.plate_number" )
        name = $redis.get("image.#{id}.name" )
        images << Image.new( image_path, plate_number, name, false, id )
      end
    end
    return images.sort_by { |e| e.id }
  end
  def self.plate_groups()
    groups = {}
    all.each do |e|
      if !groups[ [ e.plate_number, e.name ] ]
        groups.store( [ e.plate_number, e.name ], [] )
      end
      groups[ [ e.plate_number, e.name ] ] << e
    end
    groups
  end
  def self.build_model()
    model_file_path = File.join(MODEL_PATH, 'model')
    open(model_file_path, 'w') { |f| f.print('') }
    Image.plate_groups().each_with_index do |group, index|
      images = group[1]
      images.each do |image|
        open( File.join(MODEL_PATH, 'model'), 'a') do |f|
          f.puts( "#{image.image_path};#{index}")
        end
      end
    end
  end
  def self.find_by_label(input_label)
    labels, labels_plates = {}, {}
    File.read(File.join(MODEL_PATH, 'model')).split("\n").each do |ln|
      splits = ln.split(";")
      label = splits[1].to_i
      labels.store( label, []) if !labels[label]
      labels[ label ] << splits[0]
    end
    first_item = labels[input_label][0]
    $redis.keys('image.*.image_path').each do |k|
      v = $redis.get(k)
      if v == first_item
        id = k.split('.')[1]
        return Image.find_by_id(id)
      end
    end

  end
end

def get_sensor_status()
  value =`cat /sys/class/gpio/gpio21/value`.strip().to_i

  if value == 0
    #turn_motor_off()
    return true
  else
    #turn_motor_on()
    return false
  end
end

def turn_motor_on()
  `echo 1 > /sys/class/gpio/gpio4/value`
end
def turn_motor_off()
  `echo 0 > /sys/class/gpio/gpio4/value`
end

def turn_motor_two_on()
  `echo 1 > /sys/class/gpio/gpio3/value`
end

def turn_motor_two_off()
  `echo 0 > /sys/class/gpio/gpio3/value`
end

class ChapatronicsApp < Sinatra::Base

  get '/' do
    erb :inicio
  end

  get '/ajustes' do
    @current_config = YAML.load_file('./config.yml')
    erb :ajustes
  end

  post '/ajustes' do
    @new_config = { 'confidence' => params[:confidence_value], 'turnMotorOff' => params[:turnMotorOff_value],
                    'turnMotorTwoOn' => params[:turnMotorTwoOn_value], 'turnMotorTwoOff' => params[:turnMotorTwoOff_value] }

    open( './config.yml', 'w') do |f|
      f.print(@new_config.to_yaml)
    end
    redirect '/ajustes'
  end

  get '/sensor_info' do
    info = { :sensor => get_sensor_status() }
    return info.to_json
    ''
  end

  get '/turn_motor_on' do
    turn_motor_on()
    ''
  end

  get '/turn_motor_off' do
    turn_motor_off()
    ''
  end

  get '/turn_motor_two_on' do
    turn_motor_two_on()
    ''
  end

  get '/turn_motor_two_off' do
    turn_motor_two_off()
    ''
  end

  get '/registrar' do
    erb :registrar
  end

  get '/lista' do
    @plate_groups = Image.plate_groups()
    erb :lista
  end

  get '/lista/:id/eliminar' do
    keys = $redis.keys('image.*.plate_number')
    s = []
    keys.each do |k|
      v = $redis.get( k )
      if v == params[:id]
        $redis.del( k.gsub( 'plate_number', '*' ) )
        $redis.del( k.split( '.' )[0, 2].join('.') )
      end
    end
    redirect '/lista'
  end

  get '/seguimiento' do
    @config = YAML.load_file('./config.yml')
    erb :seguimiento
  end

  post '/deteccion' do
    image_path = File.join(MODEL_PATH, "capture.png" )
    raw_data = params[:image_data]
    image_data = Base64.decode64( raw_data[22, raw_data.size] )
    open( image_path, 'w') do |f|
      f.print( image_data )
    end
    output = `backend/detection #{File.join(MODEL_PATH, 'capture.png')}`.split("\n")
    label, confidence = output[0].to_i, output[1].to_f
    ref_image = Image.find_by_label( label )
    response = { 'plate_number' => ref_image.plate_number, 'name' => ref_image.name, 'label' => label, 'confidence' => confidence }
    response.to_json
  end

  post '/entrenar' do
    raw_data = params[:image_data]
    image_data = Base64.decode64( raw_data[22, raw_data.size] )
    image_path = File.join(MODEL_PATH, "#{Time.now.to_i}.png" )
    open(image_path, 'w') do |f|
      f.print(image_data)
    end
    image = Image.new( image_path, params[:plate_number], params[:name] )
    Image.build_model()
    response = { 'image_path' => image.image_path, 'plate_number' => image.plate_number, 'id' => image.id }
    response.to_json
  end

end
