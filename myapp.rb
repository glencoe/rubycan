require 'sinatra'
require 'sinatra/reloader'
require './client'


set :port, 9090

get '/' do
  client = MPDClient.new
  albums = client.get_albums_grouped
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
  client = MPDClient.new
  @token = params['token']
  indices = @token.split("-")
  albums = client.get_albums_grouped
  @albums = indices.map { |i| albums[i.to_i(16)] }
  @heading = "Random"
  haml :index
end

get '/add_album' do
  client = MPDClient.new
  album_id = params['id']
  client.add_album_by_id album_id
end

get '/artist' do
  client = MPDClient.new
  artist = params['name']
  results = client.get_albums_matching('albumartist', artist)
  @albums = results
  @heading = artist
  haml :index
end

get '/album' do
    client = MPDClient.new
    album_id = params['album_id']
    @tracks = client.get_tracks_for_album_id(album_id)
    haml :album
end

get '/css/style.min.css' do
  scss :'style'
end
