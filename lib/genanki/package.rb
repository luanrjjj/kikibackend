require 'sqlite3'
require 'zip'
require 'json'
require 'fileutils'
require 'tmpdir'
require_relative 'deck'
require_relative 'apkg_schema'
require_relative 'apkg_col'

module GenankiApp
  class Package
    attr_accessor :decks, :media_files

    def initialize(deck_or_decks = nil, media_files: nil)
      @decks = deck_or_decks.is_a?(GenankiApp::Deck) ? [deck_or_decks] : (deck_or_decks || [])
      @media_files = (media_files || []).uniq
    end

    def write_to_file(file, timestamp: nil)
      # Create a temporary directory to hold the database file
      Dir.mktmpdir do |dir|
        db_file = File.join(dir, 'collection.anki2')

        db = SQLite3::Database.new(db_file)

        timestamp ||= Time.now.to_f

        # Create an enumerator for id generation, similar to itertools.count
        start_id = (timestamp * 1000).to_i
        id_gen = Enumerator.new do |y|
          loop do
            y << start_id
            start_id += 1
          end
        end

        write_to_db(db, timestamp, id_gen)

        db.close

        Zip::File.open(file, create: true) do |zipfile|
          zipfile.add('collection.anki2', db_file)

          media_map = {}
          @media_files.each_with_index do |path, idx|
            media_map[idx.to_s] = File.basename(path)
            zipfile.add(idx.to_s, path)
          end

          zipfile.get_output_stream('media') { |f| f.write(JSON.generate(media_map)) }
        end
      end
    end

    def write_to_db(db, timestamp, id_gen)
      db.execute_batch(GenankiApp::APKG_SCHEMA)
      db.execute_batch(GenankiApp::APKG_COL)

      @decks.each do |deck|
        deck.write_to_db(db, timestamp, id_gen)
      end
    end
  end
end