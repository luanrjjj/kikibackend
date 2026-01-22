module GenankiApp
  class Card
    def initialize(ord, suspend: false)
      @ord = ord
      @suspend = suspend
    end

    def write_to_db(cursor, timestamp, deck_id, note_id, id_gen, due: 0)
      queue = @suspend ? -1 : 0
      cursor.execute('INSERT INTO cards VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);', [
        id_gen.next,     # id
        note_id,         # nid
        deck_id,         # did
        @ord,            # ord
        timestamp.to_i,  # mod
        -1,              # usn
        0,               # type (=0 for non-Cloze)
        queue,           # queue
        due,             # due
        0,               # ivl
        0,               # factor
        0,               # reps
        0,               # lapses
        0,               # left
        0,               # odue
        0,               # odid
        0,               # flags
        ""               # data
      ])
    end
  end
end