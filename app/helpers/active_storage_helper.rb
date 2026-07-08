module ActiveStorageHelper
  def safe_document_url(attachment)
    return nil unless attachment&.attached?

    begin
      # Try to generate the URL
      ActiveStorage::Current.url_options = {
        host: request.host,
        port: request.port,
        protocol: request.protocol
      }

      attachment.url
    rescue => e
      Rails.logger.error "Failed to generate document URL: #{e.message}"
      # Return a placeholder or error message
      "javascript:alert('Document not available: #{e.message}')"
    end
  end

  def safe_document_link(attachment, text = nil, options = {})
    return "Document not available" unless attachment&.attached?

    begin
      # Set URL options dynamically based on request
      ActiveStorage::Current.url_options = {
        host: request.host,
        port: request.port,
        protocol: request.protocol
      }

      url = attachment.url
      text ||= attachment.filename
      link_to text, url, { target: '_blank', class: 'btn btn-sm btn-outline-primary' }.merge(options)
    rescue => e
      Rails.logger.error "Failed to generate document link: #{e.message}"
      content_tag(:span, "Document unavailable (#{attachment.filename})", class: 'text-muted small')
    end
  end

  def document_exists?(attachment)
    return false unless attachment&.attached?

    begin
      service = attachment.blob.service
      file_path = service.send(:path_for, attachment.blob.key)
      File.exist?(file_path)
    rescue => e
      Rails.logger.error "Error checking document existence: #{e.message}"
      false
    end
  end

  def safe_document_display(attachment, options = {})
    return "No document attached" unless attachment&.attached?

    if document_exists?(attachment)
      safe_document_link(attachment, nil, options)
    else
      content_tag(:div, class: 'alert alert-warning py-2 px-3 mb-0') do
        content_tag(:small) do
          "📄 #{attachment.filename} - File missing from storage"
        end
      end
    end
  end
end