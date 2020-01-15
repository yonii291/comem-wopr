class Wopr::Ai::Wopr
  def play board, player
    minimax(board, player, {
      player => 1,
      get_opponent(player) => -1
    })
  end

  private

  DIAG = [ 0, -2 ]
  SEQ = [ 0, 1, 2 ]

  def minimax board, player, scores, depth: 0
    if winner = get_winner(board)
      return scores[winner] * scores[player]
    end

    move = nil
    score = -2

    9.times do |i|
      next if board[i] != '-'
      new_board = board.dup
      new_board[i] = player
      move_score = -minimax(new_board, get_opponent(player), scores, depth: depth + 1)
      if move_score > score
        score = move_score
        move = i
      end
    end

    return move if depth == 0
    return 0 if move.nil?
    score
  end

  def get_opponent(player)
    player == 'X' ? 'O' : 'X'
  end

  def get_winner(board)
    SEQ.each do |i|
      row = board[i * 3, 3].reject{ |p| p == '-' }
      return row.first if row.length == 3 and row.uniq.length == 1
      col = SEQ.map{ |row_index| board[row_index * 3 + i] }.reject{ |p| p == '-' }
      return col.first if col.length == 3 and col.uniq.length == 1
    end

    DIAG.each do |n|
      diag = SEQ.map{ |i| board[(n + i).abs * 3 + i] }.reject{ |p| p == '-' }
      return diag.first if diag.length == 3 and diag.uniq.length == 1
    end

    nil
  end
end