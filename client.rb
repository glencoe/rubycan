#!/usr/bin/env ruby

require 'socket'


class Album
    attr_accessor :title, :artist, :year, :album_id
    def initialize title, artist, year, album_id
        @title = title
        @artist = artist
        @year = year
        @album_id = album_id
    end
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
      while last_line != "OK\n"
        last_line = gets
        if last_line != "OK\n"
          results.push last_line.rstrip.force_encoding('utf-8')
          if last_line.start_with? "ACK"
            puts last_line
            break
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
       albums = self.get_all_albums.values
       subset = albums.sample(number)
    end

    def get_all_albums search_expression = ""
        raw_query_result = self.list "album" + search_expression + " group musicbrainz_albumid group albumartist group originaldate"
        results = Hash.new
        date = ''
        albumartist = ''
        albumid = ''
        for item in raw_query_result
            if item.start_with? 'AlbumArtist:'
                album_artist = item.delete_prefix 'AlbumArtist: '
                album_artist = album_artist.freeze
            elsif item.start_with? 'Album:'
                album_title = item.delete_prefix 'Album: ' .freeze
                results[album_title] = Album.new album_title, album_artist, date, albumid
            elsif item.start_with? 'OriginalDate'
                date = item.delete_prefix 'OriginalDate: '
                date = date.match /^\d\d\d\d/ .to_s.freeze
            elsif item.start_with? 'MUSICBRAINZ_ALBUMID'
                albumid = item.delete_prefix 'MUSICBRAINZ_ALBUMID: '
       		albumid = albumid.freeze
            end
        end
        results
    end

    def add_album album
       @socket.puts "searchadd \"(musicbrainz_albumid == \\\"#{album.album_id}\\\")\""
       status = @socket.gets
       "OK\n" == status or status
    end

    def add_albums albums
        albums.each {|album| self.add_album album} 
    end

end


def main_s
    app = Gtk::Application.new("org.gtk.example", :flags_none)
    client = MPDClient.new
    puts "connecting to mpd..."
    puts client.connect
    app.signal_connect "activate" do |application|
        window = Gtk::ApplicationWindow.new(application)
        window.set_title("Window")
        window.set_default_size(600, 600)

        button_box = Gtk::FlowBox.new()
        button_box.set_border_width 5
        button_box.set_column_spacing 5
        button_box.set_row_spacing 5
        button_box.set_min_children_per_line(3)
        button_box.set_valign(Gtk::Align::START)
        window.add(button_box)
        albums = client.get_random_albums 30
        puts albums.map {|a| a.title}
        buttons = albums.map {|album| Gtk::Button.new(label: "#{album.artist}\n#{album.title}".force_encoding('UTF-8')) }
        buttons.zip(albums).each do |button_album_pair|
            button_album_pair[0].signal_connect "clicked" do |widget|
                client.add_album button_album_pair[1]
            end
        end

        buttons.each { |button| button_box.add button }

        window.show_all
    end
    puts app.run([$0] + ARGV)
end


def add_random_albums
    client = MPDClient.new
    client.connect
    puts client.state
    values = client.get_random_albums 30
    values.each_index {|index| puts "[#{index}] (#{values[index].year}) #{values[index].artist} - #{values[index].title}" }
    selection = STDIN.gets
    selection = selection.split(',').map(&:strip).map(&:to_i).map {|index| values[index] }
    client.add_albums selection
    client.close
end

