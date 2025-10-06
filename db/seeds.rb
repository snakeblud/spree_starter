# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

Spree::Core::Engine.load_seed if defined?(Spree::Core)

# Configure store and admin user for production
if Rails.env.production?
  puts "Configuring production store..."

  # Determine store URL
  store_url = ENV['HOST'].present? ? "https://#{ENV['HOST']}" : 'http://localhost:3000'
  store_email = ENV['STORE_EMAIL'] || "store@#{ENV['HOST'] || 'localhost'}"

  # Create or update store
  store = Spree::Store.first_or_create!(
    name: ENV['STORE_NAME'] || 'My Store',
    default_currency: 'USD'
  )

  # Always update URL and email to ensure they're current
  store.update!(
    url: store_url,
    mail_from_address: store_email
  )
  puts "Store URL set to: #{store_url}"

  # Create admin user
  admin_email = ENV['ADMIN_EMAIL'] || "admin@#{ENV['HOST'] || 'localhost'}"
  admin_password = ENV['ADMIN_PASSWORD'] || 'admin123456'

  admin = Spree::User.find_or_initialize_by(email: admin_email)
  if admin.new_record?
    admin.password = admin_password
    admin.password_confirmation = admin_password
    admin.save!
    puts "Created admin user: #{admin.email}"
    puts "Admin password: #{admin_password}"
  else
    puts "Admin user already exists: #{admin.email}"
  end

  # Ensure admin has admin role
  admin_role = Spree::Role.find_or_create_by!(name: 'admin')
  unless admin.spree_roles.include?(admin_role)
    admin.spree_roles << admin_role
    puts "Granted admin role to: #{admin.email}"
  end

  puts "Store configuration complete!"
end