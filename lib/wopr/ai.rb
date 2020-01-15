class WOPR::AI
  def self.win? board, cell
    player = board[cell]
    row_index = cell / 3
    col_index = cell % 3

    # Did the player fill the row?
    board[row_index * 3, 3].all?{ |p| p == player } ||
    # Or did the player fill the column?
    SEQ.all?{ |current_row_index| board[current_row_index * 3 + col_index] == player } ||
    # Or did the player fill one of the diagonals?
    cell.even? && DIAGONALS.any?{ |diagonal| diagonal.all?{ |c| board[c] == player } }
  end

  private

  DIAGONALS = [
    # Top-left to bottom-right diagonal.
    [ 0, 4, 8 ],
    # Bottom-left to top-right diagonal.
    [ 6, 4, 2 ]
  ]

  SEQ = 0..2
end

Dir[File.join File.dirname(__FILE__), File.basename(__FILE__, '.*'), '*.rb'].each{ |lib| require lib }