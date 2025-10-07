# Middleware to remove port from request environment
# This prevents Rails from including :3000 in generated URLs
class RemovePortMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    # Remove SERVER_PORT to prevent Rails from adding it to URLs
    env.delete('SERVER_PORT')
    # Set HTTP_X_FORWARDED_PORT to standard HTTPS port
    env['HTTP_X_FORWARDED_PORT'] = '443'
    @app.call(env)
  end
end

Rails.application.config.middleware.insert_before 0, RemovePortMiddleware
