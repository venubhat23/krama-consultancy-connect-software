module CloudflareR2Helper
  # Public R2 domain from Cloudflare dashboard
  R2_PUBLIC_DOMAIN = "https://pub-54653c57ac144e4a820943b13bf076de.r2.dev"

  def cloudflare_r2_public_url(blob_or_attachment)
    return nil unless blob_or_attachment

    blob = blob_or_attachment.respond_to?(:blob) ? blob_or_attachment.blob : blob_or_attachment

    if blob && blob.service_name.to_s == 'cloudflare_r2'
      "#{R2_PUBLIC_DOMAIN}/#{blob.key}"
    else
      # Fallback to Rails blob path for other services
      blob_or_attachment.respond_to?(:url) ? blob_or_attachment.url : nil
    end
  end

  def cloudflare_r2_download_url(blob_or_attachment)
    # For downloads, we'll still use signed URLs for security
    return nil unless blob_or_attachment

    blob_or_attachment.respond_to?(:url) ? blob_or_attachment.url(disposition: 'attachment') : nil
  end
end