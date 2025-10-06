namespace :spree do
  desc "Configure store URL"
  task configure_store: :environment do
    if Spree::Store.default.present?
      Spree::Store.default.update!(
        url: ENV["HOST"] || "https://doubleclick.systems",
        mail_from_address: "noreply@doubleclick.systems"
      )
      puts "Store URL configured: #{Spree::Store.default.url}"
    else
      puts "No default store found. Run db:seed first."
    end
  end
end