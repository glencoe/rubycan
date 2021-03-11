require './client'

client = MPDClient.new
print client.get_albums_grouped
