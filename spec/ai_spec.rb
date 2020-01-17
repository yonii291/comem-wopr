require 'wopr'

RSpec.describe "AI" do
  it "should not lose" do
    empty_board = [ '-' ] * 9
    9.times do |cell|
      initial_board = empty_board.dup
      initial_board[cell] = 'X'
      wins_by_x = play_until_completion initial_board, 'O', cell, [ cell ]
      expect(wins_by_x).to be_empty
    end
  end

  private

  def play_until_completion board, player, last_cell, cells_played, wins_by_x = []
    return board[last_cell] == 'X' ? wins_by_x + [ cells_played ] : wins_by_x if WOPR::AI.win?(board, last_cell)
    return wins_by_x if board.all?{ |cell| cell != '-' }

    if player == 'X'
      possible_cells = board.each.with_index.select{ |cell,i| cell == '-' }.map{ |cell,i| i }
      scores = possible_cells.map do |cell|
        new_board = board.dup
        new_board[cell] = 'X'
        play_until_completion new_board, 'O', cell, cells_played + [ cell ]
      end
      scores.max
    else
      cell_to_play = WOPR::AI::WOPR.play board, player
      new_board = board.dup
      new_board[cell_to_play] = player
      play_until_completion new_board, 'X', cell_to_play, cells_played + [ cell_to_play ]
    end
  end

  def get_opponent player
    player == 'X' ? 'O' : 'X'
  end
end