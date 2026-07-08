# Ensure SubAgent plain_password is always synchronized with password changes
# This initializer patches the SubAgent model to maintain password visibility in admin

Rails.application.config.after_initialize do
  if defined?(SubAgent)
    SubAgent.class_eval do
      # Override password setter to ensure plain_password is always updated
      def password=(new_password)
        super(new_password)
        if new_password.present?
          self.plain_password = new_password
          Rails.logger.info "[PasswordSync] Updated plain_password for SubAgent #{id || 'new'}"
        end
      end

      # Additional callback to ensure plain_password is saved
      after_save :verify_plain_password_sync

      private

      def verify_plain_password_sync
        if saved_change_to_password_digest? && plain_password.blank?
          Rails.logger.error "[PasswordSync] WARNING: SubAgent #{id} password changed but plain_password not updated!"
        end
      end
    end

    Rails.logger.info "[PasswordSync] SubAgent password synchronization patch loaded"
  end
end