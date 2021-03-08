require 'sinatra'
require './client'

client = MPDClient.new
puts client.connect
set :port, 9090

get '/' do
  albums = client.get_all_albums
  if params['count']
    count = params['count'].to_i
  else
    count = 20
  end
  indices = (1..albums.size).to_a.sample(count).map { |i| i.to_s(16) }
  indices = indices.join('-')
  redirect to("/index?token=#{indices}")
end

get '/index' do
  @token = params['token']
  indices = @token.split("-")
  albums = client.get_all_albums.values
  @albums = indices.map { |i| albums[i.to_i(16)] }
  @heading = "Random"
  haml :index
end

get '/add' do
  album_id = params['album_id']
  client.request "searchadd \"(MUSICBRAINZ_ALBUMID == \\\"#{album_id}\\\")\""
end

get '/show' do
  artist = params['artist']
  album_id = params['album_id']
  if artist then
    results = client.get_all_albums(" \"(albumartist == \\\"#{artist}\\\")\"").values
  end
  @albums = results
  @heading = artist
  haml :index
end

get '/css/style.min.css' do
  scss :'style'
end
