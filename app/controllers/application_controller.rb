class ApplicationController < ActionController::Base
  # CSRF protection is enabled by default
  # CloudFront will properly forward the Host header
end