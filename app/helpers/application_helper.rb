module ApplicationHelper
  # Generates absolute URL for Active Storage attachments (required for OG tags)
  #
  # @param attachment [ActiveStorage::Attached::One] The attached file
  # @return [String] Absolute URL to the attachment
  def absolute_url_for(attachment)
    return nil unless attachment&.attached?
    
    # Use rails_blob_url which always generates absolute URLs
    # In production with Cloudinary, this will use the Cloudinary CDN URL
    # In development with local storage, this will use the app's host
    rails_blob_url(attachment)
  end
end
