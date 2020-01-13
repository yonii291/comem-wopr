class HomeController < ApplicationController
  def index
  end

  def play
    action = GameAction.new(params.permit(:ai, :cell, :game, :number))
    unless action.valid?
      return render json: action.errors, status: 422
    end

    previous_state_key = "wopr:#{action.game}"
    result = $redis.pipelined do
      $redis.watch previous_state_key if action.number >= 2
      $redis.get previous_state_key
    end

    current_board = result.last || "-" * 9
    if action.number >= 2 && current_board.blank?
      return render_error message: "Game not found or has expired", status: :not_found
    end

    data = current_board.split ''
    if data[action.cell] != '-'
      return render_error message: "Cell already played", status: :unprocessable_entity
    end

    data[action.cell] = 'X'
    if Ai.win?(data, 'X')
      return render_result action: action, data: data, state: 'win'
    end

    ai = case action.ai
    when 'random'
      RandomAi.new
    when 'wopr'
      WoprAi.new
    else
      return render_error message: "Unsupported AI: #{action.ai.inspect}", status: :unprocessable_entity
    end

    enemy_cell = ai.play data, 'O'
    if enemy_cell.blank?
      return render_result action: action, data: data, state: 'draw'
    end

    data[enemy_cell] = 'O'
    if Ai.win?(data, 'O')
      return render_result action: action, data: data, enemy_cell: enemy_cell, state: 'lose'
    end

    result = $redis.multi do
      $redis.set("wopr:#{action.game}", data.join(''), ex: 3600, nx: action.number == 1, xx: action.number >= 2)
    end

    if result.blank?
      return render_error message: "You tried to play twice at the same time", status: :conflict
    elsif action.number == 1 && !result[0]
      return render_error message: "You encountered a UUID collision; go buy a lottery ticket", status: 418
    elsif action.number >= 2 && !result[0]
      return render_error message: "Game not found or has expired", status: :not_found
    end

    render_result action: action, data: data, enemy_cell: enemy_cell
  end

  private

  def render_error message:, status:
    $redis.unwatch
    return render plain: message, status: status
  end

  def render_result action:, data:, enemy_cell: nil, state: 'playing'
    $redis.pipelined do
      $redis.del("wopr:#{action.game}") if state != 'playing'
      $redis.unwatch
    end

    Rails.logger.info "Game #{action.game}: #{data.join('')} (#{state})"
    render json: action.as_json({}).merge(board: data.join(''), enemyCell: enemy_cell, state: state), status: :created
  end
end
