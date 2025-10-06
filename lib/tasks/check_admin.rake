namespace :admin do
  desc "Check if admin user can authenticate"
  task check: :environment do
    email = 'admin@doubleclick.systems'
    password = 'admin123456'

    puts "Checking AdminUser authentication..."
    puts "Email: #{email}"

    # Check if user exists
    user = Spree::User.find_by(email: email)

    if user.nil?
      puts "❌ ERROR: User not found!"
      exit 1
    end

    puts "✅ User found: #{user.email}"
    puts "   ID: #{user.id}"
    puts "   Has encrypted password: #{user.encrypted_password.present?}"
    puts "   Roles: #{user.spree_roles.pluck(:name).join(', ')}"

    # Test password
    if user.valid_password?(password)
      puts "✅ Password is VALID"
    else
      puts "❌ Password is INVALID"
      puts "   Resetting password..."
      user.password = password
      user.password_confirmation = password
      if user.save
        puts "✅ Password reset successful"
        if user.valid_password?(password)
          puts "✅ Password now validates correctly"
        else
          puts "❌ Password still doesn't validate"
        end
      else
        puts "❌ Failed to save user: #{user.errors.full_messages.join(', ')}"
      end
    end

    # Check AdminUser class
    if defined?(Spree::AdminUser)
      admin_user = Spree::AdminUser.find_by(email: email)
      if admin_user
        puts "\n✅ Found as AdminUser: #{admin_user.email}"
        puts "   Can authenticate as AdminUser: #{admin_user.valid_password?(password)}"
      else
        puts "\n❌ Not found as AdminUser"
        puts "   Creating AdminUser..."
        admin_user = Spree::AdminUser.new(email: email, password: password, password_confirmation: password)
        if admin_user.save
          puts "✅ AdminUser created successfully"
        else
          puts "❌ Failed to create AdminUser: #{admin_user.errors.full_messages.join(', ')}"
        end
      end
    end
  end
end
