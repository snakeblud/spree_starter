class ApplicationController < ActionController::Base
  # Temporarily disable CSRF protection to debug 422 issue
  skip_forgery_protection
end
