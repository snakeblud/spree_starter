namespace :admin do
  desc "Create or update admin user"
  task setup: :environment do
    email = ENV['ADMIN_EMAIL'] || 'admin@doubleclick.systems'
    password = ENV['ADMIN_PASSWORD'] || 'admin123456'

    puts "Setting up admin user..."

    # Try to find or create the admin user
    admin = Spree::User.find_or_initialize_by(email: email)

    if admin.new_record?
      puts "Creating new admin user: #{email}"
    else
      puts "Updating existing user: #{email}"
    end

    admin.password = password
    admin.password_confirmation = password
    admin.save!

    # Ensure admin has admin role
    admin_role = Spree::Role.find_or_create_by!(name: 'admin')
    unless admin.spree_roles.include?(admin_role)
      admin.spree_roles << admin_role
      puts "Granted admin role"
    end

    puts "✅ Admin user ready!"
    puts "   Email: #{email}"
    puts "   Password: #{password}"
    puts "   Login at: https://#{ENV['HOST'] || 'localhost:3000'}/admin_user/sign_in"
  end
end
