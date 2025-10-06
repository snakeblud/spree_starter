class CreateAdminUser < ActiveRecord::Migration[8.0]
  def up
    return unless defined?(Spree::AdminUser)

    email = 'admin@doubleclick.systems'
    password = 'admin123456'

    # Create admin user if it doesn't exist
    admin = Spree::AdminUser.find_or_initialize_by(email: email)

    if admin.new_record?
      admin.password = password
      admin.password_confirmation = password
      admin.save!
      puts "Created AdminUser: #{email}"
    else
      puts "AdminUser already exists: #{email}"
    end
  end

  def down
    # Don't delete the admin user on rollback
  end
end
