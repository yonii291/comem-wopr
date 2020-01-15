require 'active_support/hash_with_indifferent_access'
require 'logger'
require 'sinatra'
require 'sinatra/json'
require_relative './src/backend/config'
require_relative './src/backend/game_action'
require_relative './src/backend/random_ai'
require_relative './src/backend/wopr_ai'

require 'sinatra/reloader' if CONFIG.env === 'development'

get '/' do
  slim :index, locals: { bundle: CONFIG.cached_javascript_bundle || get_javascript_bundle }
end

get '/api' do
  pkg = JSON.parse File.read(File.join(CONFIG.root_dir, 'package.json'))
  [ 200, {}, JSON.dump({ 'version' => pkg['version'] }) ]
end

post '/api/actions' do
  body = request.body.read
  action = Wopr::GameAction.new(ActiveSupport::HashWithIndifferentAccess.new(JSON.parse(body)))
  unless action.valid?
    return render_error message: "Action is invalid: #{action.errors.full_messages.join ', '}", status: 422
  end

  action = action.normalize

  previous_state_key = redis_key action.game
  result = $redis.pipelined do
    $redis.watch previous_state_key if action.number >= 2
    $redis.get previous_state_key
  end

  current_board = result.last || "-" * 9
  if action.number >= 2 && current_board.blank?
    return render_error message: "Game not found or has expired", status: 404
  end

  data = current_board.split ''
  if data[action.cell] != '-'
    return render_error message: "Cell already played", status: 422
  end

  data[action.cell] = 'X'
  if Wopr::Ai.win?(data, 'X')
    return render_result action: action, data: data, state: 'win'
  end

  ai = case action.ai
  when 'random'
    Wopr::RandomAi.new
  when 'wopr'
    Wopr::WoprAi.new
  else
    return render_error message: "Unsupported AI: #{action.ai.inspect}", status: 422
  end

  enemy_cell = ai.play data, 'O'
  if enemy_cell.blank?
    return render_result action: action, data: data, state: 'draw'
  end

  data[enemy_cell] = 'O'
  if Wopr::Ai.win?(data, 'O')
    return render_result action: action, data: data, enemy_cell: enemy_cell, state: 'lose'
  end

  result = $redis.multi do
    $redis.set(redis_key(action.game), data.join(''), ex: 3600, nx: action.number == 1, xx: action.number >= 2)
  end

  if result.blank?
    return render_error message: "You tried to play twice at the same time", status: 409
  elsif action.number == 1 && !result[0]
    return render_error message: "You encountered a UUID collision; go buy a lottery ticket", status: 418
  elsif action.number >= 2 && !result[0]
    return render_error message: "Game not found or has expired", status: 404
  end

  render_result action: action, data: data, enemy_cell: enemy_cell
end

def render_error message:, status:
  $redis.unwatch
  [ status, { 'Content-Type' => 'plain/text' }, message ]
end

def render_result action:, data:, enemy_cell: nil, state: 'playing'
  $redis.pipelined do
    $redis.del(redis_key(action.game)) if state != 'playing'
    $redis.unwatch
  end

  CONFIG.logger.info "Game #{action.game}: #{data.join('')} (#{state})"
  body = action.as_json().merge({ 'enemyCell' => enemy_cell, 'state' => state })
  [ 201, { 'Content-Type' => 'application/json' }, JSON.dump(body) ]
end