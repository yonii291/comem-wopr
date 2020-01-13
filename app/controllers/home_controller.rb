class HomeController < ApplicationController
  def index
  end

  def play
    action = GameAction.new(params.permit(:cell, :game, :number))
    unless action.valid?
      return render json: action.errors, status: 422
    end

    previous_state_key = "wopr:#{action.game}"
    result = $redis.pipelined do
      $redis.watch previous_state_key
      $redis.get previous_state_key
    end

    current_board = result[1] || "-" * 9
    if action.number >= 2 && current_board.blank?
      return render plain: "Game not found or has expired", status: :not_found
    end

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

    result = $redis.multi do
      $redis.set("wopr:#{action.game}", data.join(''), ex: 3600, nx: action.number == 1, xx: action.number >= 2)
    end

    if result.blank?
      return render plain: "You tried to play twice at the same time", status: :conflict
    elsif action.number == 1 && !result[0]
      return render plain: "You encountered a UUID collision; go buy a lottery ticket", status: 418
    elsif action.number >= 2 && !result[0]
      return render plain: "Game not found or has expired", status: :not_found
    end

    render_result action: action, data: data, enemy_cell: enemy_cell
  end

  private

  THREE = [ 0, 1, 2 ]

  def render_result action:, data:, enemy_cell: nil, state: 'playing'
    Rails.logger.info "Game #{action.game} state: #{data.join('')}"
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
