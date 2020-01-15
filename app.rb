require 'active_support/hash_with_indifferent_access'
require 'logger'
require 'sinatra'
require 'sinatra/json'

require_relative './lib/wopr'

require 'sinatra/reloader' if Config.development?

Config.ensure_database_connection!

get '/' do
  slim :index, locals: { bundle: Config.javascript_bundle }
end

get '/api' do
  json version: Config.version
end

post '/api/actions' do
  body = request.body.read
  action = Wopr::Action.new(ActiveSupport::HashWithIndifferentAccess.new(JSON.parse(body)))
  unless action.valid?
    return render_error message: "Action is invalid: #{action.errors.full_messages.join ', '}", status: 422
  end

  action = action.normalize

  previous_state_key = Config.redis_key action.game
  result = Config.redis.pipelined do
    Config.redis.watch previous_state_key if action.number >= 2
    Config.redis.get previous_state_key
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
    Wopr::Ai::Random.new
  when 'wopr'
    Wopr::Ai::Wopr.new
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

  result = Config.redis.multi do
    Config.redis.set(Config.redis_key(action.game), data.join(''), ex: 3600, nx: action.number == 1, xx: action.number >= 2)
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
  Config.redis.unwatch
  [ status, { 'Content-Type' => 'plain/text' }, message ]
end

def render_result action:, data:, enemy_cell: nil, state: 'playing'
  Config.redis.pipelined do
    Config.redis.del(Config.redis_key(action.game)) if state != 'playing'
    Config.redis.unwatch
  end

  Config.logger.info "Game #{action.game}: #{data.join('')} (#{state})"
  body = action.as_json().merge({ 'enemyCell' => enemy_cell, 'state' => state })
  [ 201, { 'Content-Type' => 'application/json' }, JSON.dump(body) ]
end