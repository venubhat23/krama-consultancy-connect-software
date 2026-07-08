namespace :storage do
  desc "Check and report Active Storage file issues"
  task health_check: :environment do
    puts "🔍 Active Storage Health Check"
    puts "=" * 50

    missing_files = []
    total_blobs = 0
    found_files = 0

    ActiveStorage::Blob.find_each do |blob|
      total_blobs += 1
      service = blob.service
      file_path = service.send(:path_for, blob.key)

      if File.exist?(file_path)
        found_files += 1
      else
        missing_files << {
          filename: blob.filename,
          key: blob.key,
          path: file_path,
          content_type: blob.content_type,
          size: blob.byte_size
        }
      end
    end

    puts "📊 Summary:"
    puts "  Total blobs: #{total_blobs}"
    puts "  Files found: #{found_files}"
    puts "  Missing files: #{missing_files.count}"
    puts

    if missing_files.any?
      puts "❌ Missing Files:"
      missing_files.each do |file|
        puts "  #{file[:filename]} (#{file[:content_type]}) - #{file[:size]} bytes"
        puts "    Key: #{file[:key]}"
        puts "    Expected at: #{file[:path]}"
        puts
      end

      puts "🔧 To fix missing files, you can:"
      puts "1. Re-upload the files through the application"
      puts "2. Use the new safe document access URLs: /admin/documents/blob/{key}"
      puts "3. Run 'rails storage:cleanup_orphaned' to remove blob records for missing files"
    else
      puts "✅ All files are present!"
    end
  end

  desc "Remove blob records for missing files"
  task cleanup_orphaned: :environment do
    puts "🧹 Cleaning up orphaned blob records..."

    removed_count = 0
    ActiveStorage::Blob.find_each do |blob|
      service = blob.service
      file_path = service.send(:path_for, blob.key)

      unless File.exist?(file_path)
        puts "Removing blob record for missing file: #{blob.filename}"
        blob.destroy
        removed_count += 1
      end
    end

    puts "✅ Removed #{removed_count} orphaned blob records"
  end

  desc "Generate placeholder files for missing attachments"
  task create_placeholders: :environment do
    puts "📄 Creating placeholder files..."

    created_count = 0
    ActiveStorage::Blob.find_each do |blob|
      service = blob.service
      file_path = service.send(:path_for, blob.key)

      unless File.exist?(file_path)
        # Create directory if it doesn't exist
        FileUtils.mkdir_p(File.dirname(file_path))

        # Create a placeholder file
        placeholder_content = generate_placeholder_content(blob)
        File.write(file_path, placeholder_content)

        puts "Created placeholder for: #{blob.filename}"
        created_count += 1
      end
    end

    puts "✅ Created #{created_count} placeholder files"
  end

  private

  def generate_placeholder_content(blob)
    case blob.content_type
    when 'application/pdf'
      # Create a simple PDF placeholder
      "%PDF-1.4\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>\nendobj\nxref\n0 4\n0000000000 65535 f \n0000000010 00000 n \n0000000079 00000 n \n0000000173 00000 n \ntrailer\n<< /Size 4 /Root 1 0 R >>\nstartxref\n253\n%%EOF"
    when /^image\//
      # For images, create a simple text placeholder
      "Image file not available: #{blob.filename}\nOriginal size: #{blob.byte_size} bytes\nContent type: #{blob.content_type}"
    else
      # Generic text placeholder
      "Document not available: #{blob.filename}\nOriginal size: #{blob.byte_size} bytes\nContent type: #{blob.content_type}\nThis is a placeholder file generated because the original was missing."
    end
  end
end