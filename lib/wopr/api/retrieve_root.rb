module WOPR::API
  def self.retrieve_root sinatra
    render_resource resource: {
      'version' => WOPR::VERSION
    }
  end
end