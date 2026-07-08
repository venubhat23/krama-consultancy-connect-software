class R2Service
  # Constants defined in class
  R2_BUCKET = "dr-wise-software"
  R2_PUBLIC_DOMAIN = "https://pub-5c8ca1934dba43a9bc18041c326adce0.r2.dev"

  class << self
    # Upload file to R2
    def upload(file, folder: nil)
      # Generate unique key
      key = generate_key(file.original_filename, folder)

      # Upload to R2
      r2_client.put_object(
        bucket: R2_BUCKET,
        key: key,
        body: file.tempfile,
        content_type: file.content_type
      )

      {
        key: key,
        filename: file.original_filename,
        content_type: file.content_type,
        size: file.size,
        public_url: public_url(key)
      }
    rescue => e
      Rails.logger.error "R2 Upload Error: #{e.message}"
      { error: e.message }
    end

    # Download file from R2
    def download(key)
      r2_client.get_object(
        bucket: R2_BUCKET,
        key: key
      )
    rescue => e
      Rails.logger.error "R2 Download Error: #{e.message}"
      nil
    end

    # Delete file from R2
    def delete(key)
      r2_client.delete_object(
        bucket: R2_BUCKET,
        key: key
      )
      true
    rescue => e
      Rails.logger.error "R2 Delete Error: #{e.message}"
      false
    end

    # Check if file exists
    def exists?(key)
      r2_client.head_object(
        bucket: R2_BUCKET,
        key: key
      )
      true
    rescue
      false
    end

    # Get public URL for file
    def public_url(key)
      "#{R2_PUBLIC_DOMAIN}/#{key}"
    end

    # Get signed URL (for downloads)
    def signed_url(key, expires_in: 1.hour)
      signer = Aws::S3::Presigner.new(client: r2_client)
      signer.presigned_url(
        :get_object,
        bucket: R2_BUCKET,
        key: key,
        expires_in: expires_in.to_i
      )
    end

    # Get R2 client instance
    def r2_client
      @r2_client ||= Aws::S3::Client.new(
        access_key_id: "52ed60ae0a0776fb357299dede45ab9f",
        secret_access_key: "5b19ea5dede62f503eebb2b57de7719962f38d6b86ef387f993bcf0d6102f657",
        region: "auto",
        endpoint: "https://1f8982473cb9a48a41c053ca18db87ca.r2.cloudflarestorage.com",
        force_path_style: true
      )
    end

    private

    def generate_key(filename, folder = nil)
      timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
      random_string = SecureRandom.hex(8)
      extension = File.extname(filename)
      base_name = File.basename(filename, extension)

      key = "#{timestamp}_#{random_string}_#{base_name}#{extension}"
      folder ? "#{folder}/#{key}" : key
    end
  end
end