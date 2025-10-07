namespace :spree do
  namespace :sample do
    desc "Upload sample product images to Active Storage (S3)"
    task upload_images_to_s3: :environment do
      puts "Uploading sample product images to S3..."

      Spree::Product.find_each do |product|
        # Skip if product already has images in Active Storage
        next if product.images.attached?

        # Get the product's master variant images
        product.master.images.each do |image|
          next unless image.attachment.present?

          # The image attachment already exists, we just need to ensure it's in S3
          blob = image.attachment.blob

          if blob.service_name != Rails.application.config.active_storage.service.to_s
            puts "Uploading image for product: #{product.name}"

            # Download the image data
            image_data = blob.download

            # Create a new blob in the correct storage service
            new_blob = ActiveStorage::Blob.create_and_upload!(
              io: StringIO.new(image_data),
              filename: blob.filename,
              content_type: blob.content_type
            )

            # Update the attachment to use the new blob
            image.attachment.update!(blob: new_blob)
          end
        end

        # Also handle variant images
        product.variants.each do |variant|
          variant.images.each do |image|
            next unless image.attachment.present?

            blob = image.attachment.blob

            if blob.service_name != Rails.application.config.active_storage.service.to_s
              puts "Uploading image for variant: #{variant.sku}"

              image_data = blob.download

              new_blob = ActiveStorage::Blob.create_and_upload!(
                io: StringIO.new(image_data),
                filename: blob.filename,
                content_type: blob.content_type
              )

              image.attachment.update!(blob: new_blob)
            end
          end
        end
      end

      puts "Done! Sample images uploaded to S3."
    end
  end
end
