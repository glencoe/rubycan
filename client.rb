#!/usr/bin/env ruby

require 'socket'

module LibraryEntity
    def set_tag(tag_symbol, value)
       tag_symbol = tag_symbol.to_s.downcase.gsub(/-/, "_")
       self.class.send(:attr_accessor, tag_symbol)
       send((tag_symbol.to_s + "=").to_sym, value)
    end
end

class Track
    include LibraryEntity
end


class Album
    include LibraryEntity
    attr_accessor :album, :albumartist, :year, :musicbrainz_albumid, :originaldate, :genre
    def title= t
        @album = t
    end

    def title
        @album
    end

    def artist
        @albumartist
    end

    def album_id
        @musicbrainz_albumid
    end

    def year
        @originaldate.match(/^\d\d\d\d/)
    end
end

class MPDException < StandardError
    
end

TAGS = [:AlbumArtist, :Album, :MUSICBRAINZ_ALBUMID,
	:AlbumArtistSort, :AlbumSort, :OriginalDate,
	:Title, :Artist, :ArtistSort, :Genre,
	:Name, :Track, :Disc, :MUSICBRAINZ_ARTISTID,
	:MUSICBRAINZ_ALBUMARTISTID, :MUSICBRAINZ_RELEASETRACKID,
	:MUSICBRAINZ_TRACKID, :Label]

def string_to_tag(s)
    s = s.downcase
    tag = TAGS.filter do |tag|
        tag.to_s.downcase == s
    end
    tag[0]
end

class MPDClient
    attr_reader :state
    
    def initialize
        @host_name = "alarmpi"
        @port = 6600
    end

    def connect
        @socket = TCPSocket.new(@host_name, @port)
        initial_response = @socket.gets
        if not initial_response.start_with? "OK"
           @state = "fail"
        else
           @state = "success"
        end
    end

    def close
        @socket.close
    end

    def puts content
        @socket.puts content
    end

    def gets
        @socket.gets
    end

    def request content
      connect
      puts content
      last_line = ""
      results = []
      while last_line != "OK\n" and not last_line.start_with?("ACK@")
        last_line = gets
        if last_line != "OK\n"
          if last_line.start_with? "ACK"
            raise MPDException.new("#{last_line.delete_prefix('ACK@')} command: #{content}")
          else
            line_values = last_line.rstrip.force_encoding('utf-8').split(":")
            tag = :"#{line_values[0]}"
            value = line_values[1..].join(':').rstrip.lstrip
            results.push({tag => value})
          end
        end
      end
      close
      results
    end

    def list query
      request "list #{query}"
    end

    def get_random_albums number
       albums = self.get_albums_grouped
       subset = albums.sample(number)
    end

    def create_match_query tag, value
       " \"(#{tag} == \\\"#{value}\\\")\""
    end

    def get_albums_matching tag, value
        get_albums_grouped(search_expression: create_match_query(tag, value))
    end

    def status
        s = request("status")
        s.reduce({}) { |accumulator, new_value| accumulator.merge(new_value) }
    end

    def get_tracks_for_album_id(album_id)
        result = request("find" + create_match_query(:MUSICBRAINZ_ALBUMID.to_s, album_id))
        result = result.reduce([]) do |tracks, tag|
            if tag.has_key?(:file)
                tracks.push(Track.new)
            end
            tag.each_pair do |key, value|
                tracks.last.set_tag(key, value)
            end
            tracks
        end

        result
    end

    def get_albums_grouped(groups: [:MUSICBRAINZ_ALBUMID, :AlbumArtist, :Genre, :OriginalDate], search_expression: "")
        result = request((["list album #{search_expression}"] | groups ).join(" group "))
        result = result.reduce([]) do | albums, tag |
            if tag.has_key?(groups[-1])
                albums = albums.push(Album.new)
            end
            albums.last.method("#{tag.keys[0].to_s.downcase}=".to_sym).call tag.values[0]
            albums
        end
    end

    def add_album_by_id album_id
        request("searchadd" + create_match_query(:MUSICBRAINZ_ALBUMID.to_s, album_id))
    end
end
