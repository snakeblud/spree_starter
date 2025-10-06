module Spree
  module Admin
    module AdminUsers
      class SessionsController < Devise::SessionsController
        helper 'spree/base'

        layout 'spree/layouts/admin'

        protected

        def after_sign_in_path_for(resource)
          spree.admin_path
        end

        def after_sign_out_path_for(resource_or_scope)
          new_admin_user_session_path
        end
      end
    end
  end
end
