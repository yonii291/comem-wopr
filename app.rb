require 'logger'
require 'sinatra'
require 'sinatra/json'

require_relative './lib/wopr'

require 'sinatra/reloader' if WOPR.development?

WOPR.ensure_database_connection!
WOPR.logger.info Paint["WOPR is running in #{WOPR.env} mode", :green]

set :bind, '0.0.0.0'
set :port, WOPR.port

get '/' do
  slim :index, locals: { bundle: WOPR.javascript_bundle }
end

get '/api' do
  WOPR::API.retrieve_root self
end

post '/api/actions' do
  WOPR::API.create_action self
end
