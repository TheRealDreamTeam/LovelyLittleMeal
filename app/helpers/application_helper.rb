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

  # Generates absolute URL for files in public directory (required for OG tags)
  #
  # @param path [String] Path relative to public directory (e.g., "llm-og-logo.jpg")
  # @return [String] Absolute URL to the file
  def public_file_url(path)
    # Remove leading slash if present
    path = path.sub(/^\//, '')
    # Generate absolute URL using request base URL
    "#{request.base_url}/#{path}"
  end
end
