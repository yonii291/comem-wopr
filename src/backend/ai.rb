module Wopr
  class Ai
    DIAG = [ 0, -2 ]
    SEQ = [ 0, 1, 2 ]

    def self.win?(board, player)
      # row win
      SEQ.any?{ |row_index| board[row_index * 3, 3] == [ player ] * 3 } or
      # col win
      SEQ.any?{ |col_index| SEQ.all?{ |row_index| board[row_index * 3 + col_index] == player } } or
      # top-left to bottom-right diagonal win
      SEQ.all?{ |i| board[i * 3 + i] == player } or
      # bottom-left to top-right diagonal win
      SEQ.all?{ |i| board[(2 - i) * 3 + i] == player }
    end
  end
end