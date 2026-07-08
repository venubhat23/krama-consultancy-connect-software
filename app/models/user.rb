require 'bcrypt'

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Override Devise's authentication to support mobile number login
  attr_writer :login

  def login
    @login || self.email
  end

  def self.find_for_database_authentication(warden_conditions)
    conditions = warden_conditions.dup
    if login = conditions.delete(:login)
      # Try email first
      user = where(conditions.to_hash).where(["lower(email) = :value", { :value => login.downcase }]).first

      # If not found by email, try mobile number with flexible formatting
      unless user
        formatted_mobile = format_mobile_number(login)
        if formatted_mobile
          # Try multiple mobile format variations
          user = where(conditions.to_hash).where(mobile: formatted_mobile).first ||
                 where(conditions.to_hash).where(mobile: "+91#{formatted_mobile}").first ||
                 where(conditions.to_hash).where(mobile: "+91 #{formatted_mobile}").first ||
                 where(conditions.to_hash).where(mobile: "#{formatted_mobile[0..4]} #{formatted_mobile[5..9]}").first ||
                 where(conditions.to_hash).where(mobile: "+91 #{formatted_mobile[0..4]} #{formatted_mobile[5..9]}").first ||
                 where(conditions.to_hash).where("REPLACE(REPLACE(mobile, ' ', ''), '+91', '') = ?", formatted_mobile).first
        else
          # If format_mobile_number returns nil, try direct mobile search as fallback
          user = where(conditions.to_hash).where(mobile: login).first
        end
      end

      # If not found by email or mobile, try PAN number (case-insensitive)
      unless user
        user = where(conditions.to_hash).where(["upper(pan_number) = :value", { :value => login.upcase }]).first
      end

      # Also check in Customer table for login with mobile/PAN/email
      unless user
        customer = Customer.where(["lower(email) = :value OR mobile = :value OR upper(pan_number) = :value",
                                  { :value => login.downcase }]).first
        if customer
          # Find associated user by email or create one
          user = where(email: customer.email).first if customer.email.present?
        end
      end

      user
    else
      if conditions.has_key?(:email)
        where(conditions.to_hash).first
      else
        where(conditions.to_hash).first
      end
    end
  end
  include PgSearch::Model

  # Associations
  belongs_to :role, optional: true
  belongs_to :user_role, optional: true
  belongs_to :forum, optional: true
  belongs_to :chapter, optional: true
  has_many :policies, dependent: :destroy
  has_one_attached :profile_image
  has_many_attached :documents
  has_many :uploaded_documents, as: :documentable, class_name: 'Document', dependent: :destroy
  has_many :support_tickets, foreign_key: :raised_by_id, dependent: :destroy, inverse_of: :raised_by
  has_many :event_registrations, dependent: :destroy
  has_many :registered_events, through: :event_registrations, source: :event
  has_many :created_announcements, class_name: 'Announcement', foreign_key: :created_by_id, dependent: :destroy, inverse_of: :created_by

  # Validations
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :mobile, presence: true, uniqueness: true
  validates :user_type, presence: true, inclusion: { in: ['admin', 'agent', 'sub_agent', 'customer', 'ambassador', 'investor', 'forum_admin', 'chapter_admin', 'member'] }
  validates :forum, presence: true, if: -> { %w[forum_admin chapter_admin member].include?(user_type) }
  validates :chapter, presence: true, if: -> { %w[chapter_admin member].include?(user_type) }
  validate :within_forum_member_limit, on: :create, if: -> { user_type == 'member' }
  # Note: role validation can be added later when roles are set up

  # Enums
  enum :user_type, { admin: 'admin', agent: 'agent', sub_agent: 'sub_agent', customer: 'customer', ambassador: 'ambassador', investor: 'investor', forum_admin: 'forum_admin', chapter_admin: 'chapter_admin', member: 'member' }

  # Callbacks
  before_validation :assign_session_token, on: :create
  after_update :role_changed_callback

  # Scopes
  scope :active, -> { where(status: true) }
  scope :inactive, -> { where(status: false) }
  scope :by_type, ->(type) { where(user_type: type) }

  # Search
  pg_search_scope :search_users,
    against: [:first_name, :last_name, :email, :mobile, :pan_number],
    using: {
      tsearch: { prefix: true, any_word: true }
    }

  # Instance methods
  def full_name
    "#{first_name} #{last_name}".strip
  end

  def active?
    status
  end

  # Role-based permission methods
  # Note: role_name is also an attribute (column), this method provides association fallback
  def role_display_name_from_association
    role&.name
  end

  def role_display_name
    role&.display_name || 'No Role Assigned'
  end

  def has_role?(role_name)
    return false unless role
    role.name == role_name.to_s
  end

  def has_permission?(module_name, action_type)
    return false unless role

    # Get user abilities
    role.permissions.pluck(:module_name, :action_type).include?([module_name.to_s, action_type.to_s])
  end

  def can_access_module?(module_name)
    return false unless role
    role.permissions.exists?(module_name: module_name.to_s)
  end

  def accessible_modules
    return [] unless role
    role.permissions.distinct.pluck(:module_name)
  end

  def module_permissions(module_name)
    return [] unless role
    role.permissions.where(module_name: module_name.to_s).pluck(:action_type)
  end

  # Password reset tracking methods
  def password_reset_days
    return 0 unless respond_to?(:password_reset_at) && password_reset_at
    ((Time.current - password_reset_at) / 1.day).to_i
  end

  def password_reset_required?
    return false unless respond_to?(:password_reset_at) && password_reset_at
    password_reset_days >= 180
  end

  def days_until_password_expires
    return 180 unless respond_to?(:password_reset_at) && password_reset_at
    [180 - password_reset_days, 0].max
  end

  def mark_password_reset!
    update_column(:password_reset_at, Time.current) if respond_to?(:password_reset_at) && User.column_names.include?('password_reset_at')
  end

  # Override Devise password update to track reset
  def update_password(params, *options)
    result = super
    if result && password_changed?
      mark_password_reset!
    end
    result
  end

  # Sidebar permissions methods
  def sidebar_permissions_array
    return [] if sidebar_permissions.blank?

    begin
      parsed = if sidebar_permissions.is_a?(String)
        JSON.parse(sidebar_permissions)
      elsif sidebar_permissions.is_a?(Array)
        sidebar_permissions
      else
        []
      end

      # If it's the new CRUD format (hash), extract the keys
      if parsed.is_a?(Hash)
        parsed.keys
      else
        # Old format (array)
        parsed
      end
    rescue JSON::ParserError
      []
    end
  end

  # Get permissions in CRUD format (for compatibility)
  def sidebar_permissions_hash
    return {} if sidebar_permissions.blank?

    begin
      parsed = if sidebar_permissions.is_a?(String)
        JSON.parse(sidebar_permissions)
      else
        sidebar_permissions
      end

      # If it's already a hash (CRUD format), return it
      if parsed.is_a?(Hash)
        parsed
      else
        # Convert old array format to CRUD format (view-only)
        result = {}
        parsed.each do |permission|
          result[permission] = { 'view' => true, 'create' => false, 'edit' => false, 'delete' => false }
        end
        result
      end
    rescue JSON::ParserError
      {}
    end
  end

  def has_sidebar_permission?(permission_key)
    return true if email == 'admin@drwise.com'

    permissions = sidebar_permissions_hash
    permission_data = permissions[permission_key.to_s]

    return false if permission_data.nil?

    # Show in sidebar if user has ANY permission for this module
    permission_data['view'] == true ||
      permission_data['create'] == true ||
      permission_data['edit'] == true ||
      permission_data['delete'] == true
  end

  def update_sidebar_permissions(permissions)
    self.update(sidebar_permissions: permissions.to_json)
  end

  # Legacy support for existing code that checks user_type
  def admin?
    user_type == 'admin'
  end

  def can_view_reports?
    admin? || %w[admin agent].include?(user_type)
  end

  def agent?
    user_type == 'agent'
  end

  def customer?
    user_type == 'customer'
  end

  def ambassador?
    user_type == 'ambassador'
  end

  def investor?
    user_type == 'investor'
  end

  def super_admin?
    has_role?('super_admin')
  end

  def forum_admin?
    user_type == 'forum_admin'
  end

  def chapter_admin?
    user_type == 'chapter_admin'
  end

  def member?
    user_type == 'member'
  end

  def force_logout!
    update_column(:session_token, SecureRandom.hex(16))
  end

  # Clear abilities cache when role changes
  def clear_abilities_cache
    Rails.cache.delete("user_#{id}_abilities")
  end

  # Override password_digest method to fix serialization issues
  # The User model uses Devise (encrypted_password) but has a password_digest column
  # This causes conflicts during serialization - override to prevent errors
  def password_digest(password = nil)
    # If called with password argument, use BCrypt like has_secure_password would
    if password
      BCrypt::Password.create(password)
    else
      # For serialization (no arguments), return the stored value or nil
      super() if respond_to?(:super) rescue nil
    end
  end

  private

  # Clear cache when role changes
  def role_changed_callback
    clear_abilities_cache if role_id_changed?
  end

  def assign_session_token
    self.session_token ||= SecureRandom.hex(16)
  end

  def within_forum_member_limit
    return unless forum
    if forum.member_limit_reached?
      errors.add(:base, "#{forum.name} has reached its #{forum.business_plan.name} plan limit of #{forum.business_plan.member_limit} members. Ask the platform admin to upgrade the plan.")
    end
  end

  # Mobile number formatting helper (flexible for various formats)
  def self.format_mobile_number(mobile)
    return nil if mobile.blank?
    # Remove all non-digit characters
    clean_mobile = mobile.to_s.gsub(/\D/, '')

    # Handle different mobile number formats
    if clean_mobile.length == 10
      # Standard 10-digit format, accept all (for testing purposes)
      return clean_mobile
    elsif clean_mobile.length == 12 && clean_mobile.start_with?('91')
      # 12 digits starting with 91
      return clean_mobile[2..-1]
    elsif clean_mobile.length == 13 && clean_mobile.start_with?('+91')
      # +91 prefix with spaces removed
      return clean_mobile[3..-1]
    else
      return nil
    end
  end
end
