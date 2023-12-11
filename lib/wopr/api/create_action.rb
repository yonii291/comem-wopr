module WOPR::API
  def self.create_action app

    # Parse the game action.
    action = WOPR::Action.new parse_request_body(app)
    return render_action_error message: "Action is invalid: #{action.errors.full_messages.join ', '}", status: 422 unless action.valid?

    action = action.normalize

    # Get the previous game and watch the key for optimistic locking (see
    # https://redis.io/topics/transactions#optimistic-locking-using-check-and-set).
    previous_state_key = WOPR.redis_key action.game
    WOPR.redis.watch(previous_state_key) if action.number >= 2
    result = WOPR.redis.get(previous_state_key)

    # Get or initialize the board.
    current_board = result || "-" * 9
    return render_action_error message: "Game not found or has expired", status: 404 if action.number >= 2 && current_board.blank?

    # Split the board into its 9 cells and check if the action's cell is free.
    data = current_board.split ''
    return render_action_error message: "Cell already played", status: 422 if data[action.cell] != '-'

    # Perform the action and check whether the player has won.
    data[action.cell] = 'X'
    return render_created_action action: action, data: data, state: 'win' if WOPR::AI.win?(data, action.cell)

    # Otherwise select the AI that will play as the opponent.
    ai = case action.ai
    when 'random'
      WOPR::AI::Random
    when 'wopr'
      WOPR::AI::WOPR
    else
      return render_action_error message: "Unsupported AI: #{action.ai.inspect}", status: 422
    end

    # Determine the AI's action. If there is no possible action, the game is a draw.
    enemy_cell = ai.play data, 'O'
    return render_created_action action: action, data: data, state: 'draw' if enemy_cell.blank?

    # Perform the AI's action and check whether it has won.
    data[enemy_cell] = 'O'
    return render_created_action action: action, data: data, enemy_cell: enemy_cell, state: 'lose' if WOPR::AI.win?(data, enemy_cell)

    # Persist the new game state and set it to expire after 1 hour.
    #
    # For a new game, the NX option is given to the SET command so that it is
    # only created if it does not already exist.
    #
    # For an existing game, the XX option is given to the SET command so that
    # the game is only updated if it still exists.
    result = WOPR.redis.multi do |multi|
      multi.set(WOPR.redis_key(action.game), data.join(''), ex: 3600, nx: action.number == 1, xx: action.number >= 2)
    end

    # Return the appropriate error message if the previous operation failed.
    if result.blank?
      return render_action_error message: "You tried to play twice at the same time", status: 409
    elsif action.number == 1 && !result[0]
      return render_action_error message: "You are either trying to create a game that already exists, or you encountered a UUID collision (if so, go buy a lottery ticket)", status: 418
    elsif action.number >= 2 && !result[0]
      return render_action_error message: "Game not found or has expired", status: 404
    end

    # The game continues.
    render_created_action action: action, data: data, enemy_cell: enemy_cell
  end

  private

  def self.render_action_error **kwargs
    # Unwatch the game state key to cancel the optimistic lock.
    WOPR.redis.unwatch
    render_error **kwargs
  end

  def self.render_created_action action:, data:, enemy_cell: nil, state: 'playing'
    WOPR.redis.pipelined do |pipeline|
      # Delete the game when done.
      pipeline.del(WOPR.redis_key(action.game)) if state != 'playing'
      # Unwatch the game state key to cancel the optimistic lock (in case it is
      # still ongoing).
      pipeline.unwatch
    end

    WOPR.logger.info "Game #{action.game}: #{data.join('')} (#{state})"
    render_created_resource resource: action.as_json().merge({ 'enemyCell' => enemy_cell, 'state' => state })
  end
end