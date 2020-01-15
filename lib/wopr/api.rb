require 'active_support/hash_with_indifferent_access'

module WOPR::API
  private

  def self.parse_request_body app
    begin
      json = JSON.parse app.request.body.read
      ActiveSupport::HashWithIndifferentAccess.new json
    rescue JSON::ParserError => e
      return render_action_error message: "JSON is invalid: #{e}", status: 400
    end
  end

  def self.render_error message:, status:
    [ status, { 'Content-Type' => 'plain/text' }, message ]
  end

  def self.render_created_resource resource:
    render_resource resource: resource, status: 201
  end

  def self.render_resource resource:, status: 200
    [ status, { 'Content-Type' => 'application/json' }, JSON.dump(resource) ]
  end
end

Dir[File.join File.dirname(__FILE__), File.basename(__FILE__, '.*'), '*.rb'].each{ |lib| require lib }