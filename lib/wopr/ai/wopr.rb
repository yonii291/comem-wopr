class WOPR::AI::WOPR
  def self.play board, player
    minimax board, player, {
      player => 1,
      get_opponent(player) => -1
    }
  end

  private

  # Recursively find the best cell to play on the current board, using a minimax
  # algorithm and assuming a perfect opponent.
  #
  # https://towardsdatascience.com/tic-tac-toe-creating-unbeatable-ai-with-minimax-algorithm-8af9e52c1e7d
  def self.minimax board, player, scores, depth: 0, last_cell: nil

    # Return 1 for a win by the current player, or -1 for a win by the opponent.
    if winner = get_winner(board, last_cell)
      return scores[winner] * scores[player]
    end

    cells_to_play = []
    score = -2

    9.times do |current_cell|
      next if board[current_cell] != '-'

      # Play in the current cell.
      new_board = board.dup
      new_board[current_cell] = player

      # Compute and negate the minimax score for the opponent after playing in
      # that cell:
      #
      # * If the opponent loses, -1 is returned, so the cell is valued at +1.
      # * If the new game state allows the opponent to win, 1 is returned, so
      #   the cell is valued at -1.
      # * If the new game state leads to a draw (assuming a perfect opponent),
      #   the cell is valued at 0.
      cell_score = -minimax(new_board, get_opponent(player), scores, depth: depth + 1, last_cell: current_cell)
      if cell_score > score
        score = cell_score
        cells_to_play = [ current_cell ]
      elsif cell_score == score
        cells_to_play << current_cell
      end
    end

    # Return one of the best cells to play (or nil if it's a draw) when done
    # with the recursive algorithm.
    return cells_to_play.shuffle.first if depth == 0

    # Return the minimax score or 0 if there are no remaining cells (i.e. draw).
    cells_to_play.empty? ? 0 : score
  end

  def self.get_opponent(player)
    player == 'X' ? 'O' : 'X'
  end

  def self.get_winner(board, last_cell)
    last_cell && WOPR::AI.win?(board, last_cell) ? board[last_cell] : nil
  end
end