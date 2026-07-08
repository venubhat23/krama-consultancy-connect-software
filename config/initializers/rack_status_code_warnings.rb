# Suppress Rack deprecation warnings from Devise
# This is a temporary fix until Devise updates to use :unprocessable_content instead of :unprocessable_entity

module RackStatusCodeWarningSuppress
  def warn(msg, category: nil)
    return if msg =~ /Status code :unprocessable_entity is deprecated/
    super
  end
end

Warning.extend(RackStatusCodeWarningSuppress)