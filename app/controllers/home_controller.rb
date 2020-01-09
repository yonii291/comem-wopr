class HomeController < ApplicationController
  def index
  end

  def play
    action = GameAction.new(params.permit(:cell, :game, :number))
    unless action.valid?
      return render json: action.errors, status: 422
    end

    previous_state_key = "wopr:#{action.game}:#{action.number - 1}"
    current_board = if action.number >= 2
      result = $redis.multi do
        $redis.get previous_state_key
        $redis.del previous_state_key
      end

      result[0]
    else
      "-" * 9
    end

    return render plain: "Game not found or has expired", status: :not_found if current_board.blank?

    data = current_board.split ''
    data[action.cell] = 'X'

    if win?(data, 'X')
      return render_result action: action, data: data, state: 'win'
    end

    enemy_cell = data.dup.each_with_index.map{ |value,i| value == '-' ? i : nil }.select{ |i| i }.shuffle.first
    if enemy_cell.blank?
      return render_result action: action, data: data, state: 'draw'
    end

    data[enemy_cell] = 'O'
    if win?(data, 'O')
      return render_result action: action, data: data, enemy_cell: enemy_cell, state: 'lose'
    end

    unless $redis.set("wopr:#{action.game}:#{action.number}", data.join(''), ex: 3600, nx: true)
      return render plain: "You tried to play twice at the same time", status: :conflict
    end

    render_result action: action, data: data, enemy_cell: enemy_cell
  end

  private

  THREE = [ 0, 1, 2 ]

  def render_result action:, data:, enemy_cell: nil, state: 'playing'
    render json: action.as_json({}).merge(board: data.join(''), enemyCell: enemy_cell, state: state), status: :created
  end

  def win?(board_data, value)
    # row win
    THREE.any?{ |row_index| board_data[row_index * 3, 3] == [ value ] * 3 } or
    # col win
    THREE.any?{ |col_index| THREE.all?{ |row_index| board_data[row_index * 3 + col_index] == value } } or
    # top-left to bottom-right diagonal win
    THREE.all?{ |i| board_data[i * 3 + i] == value } or
    # bottom-left to top-right diagonal win
    THREE.all?{ |i| board_data[(2 - i) * 3 + i] == value }
  end
end
