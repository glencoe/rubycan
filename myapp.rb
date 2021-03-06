require 'sinatra'
require './client'

client = MPDClient.new
puts client.connect
enable :sessions
set :port => 9090

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
  @random_albums = indices.map { |i| albums[i.to_i(16)] }
  print @random_albums.size
  haml :index
end

get '/add' do
  token = params['token']
  puts token
  album_id = params['album_id']
  client.request "searchadd \"(MUSICBRAINZ_ALBUMID == \\\"#{album_id}\\\")\""
  redirect to("/index?token=#{token}")
end
