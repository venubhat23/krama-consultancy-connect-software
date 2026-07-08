# WickedPDF Configuration
WickedPdf.configure do |config|
  # Path to wkhtmltopdf executable (usually auto-detected)
  # config.exe_path = '/usr/local/bin/wkhtmltopdf'

  # Enable JavaScript (if needed for charts, etc.)
  config.enable_local_file_access = true
  config.javascript_delay = 1000

  # Default options for all PDFs
  config.orientation = 'Portrait'
  config.page_size = 'A4'
  config.margin = {
    top: 10,
    bottom: 10,
    left: 10,
    right: 10
  }

  # Footer with page numbers
  config.footer = {
    right: '[page] of [topage]',
    font_size: 8
  }
end

# Mime type registration for PDF format
Mime::Type.register "application/pdf", :pdf