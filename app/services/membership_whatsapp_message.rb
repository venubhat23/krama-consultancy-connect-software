# Builds a click-to-chat (wa.me) WhatsApp link with copy tailored to the
# application's current stage. No WhatsApp Business API involved — the admin
# taps the link, WhatsApp opens with the message prefilled, and sends it.
class MembershipWhatsappMessage
  include Rails.application.routes.url_helpers

  def self.for(application)
    new(application).build
  end

  def initialize(application)
    @application = application
  end

  def build
    message = text
    { text: message, url: whatsapp_url(message) }
  end

  private

  attr_reader :application

  def text
    case application.status.to_sym
    when :invited
      application.event_led? ? invited_to_event_text : invited_to_join_text
    when :confirmed
      "Hi #{first_name}, you're confirmed for #{event_name}! See you there. #{link}"
    when :attended
      "Hi #{first_name}, thanks for coming to #{event_name}! We'd love your quick feedback: #{link}"
    when :feedback_collected
      if application.join_invite_sent_at.present?
        "Hi #{first_name}, we'd love to have you join #{forum_name}. Continue here: #{link}"
      else
        "Hi #{first_name}, thanks for the feedback! We'll be in touch soon. #{link}"
      end
    when :interested
      "Hi #{first_name}, great to hear you're interested in #{forum_name}! Please complete your membership KYC here: #{link}"
    when :kyc_submitted, :under_review
      "Hi #{first_name}, thanks for submitting your details. Your application to #{forum_name} is under review — track it here: #{link}"
    when :approved
      "Hi #{first_name}, good news — your application to #{forum_name} is approved! Next steps and payment details: #{link}"
    when :paid
      "Hi #{first_name}, we've received your payment and are finalizing your membership. #{link}"
    when :member
      "Welcome to #{forum_name}, #{first_name}! Your membership is now active. #{link}"
    when :rejected
      "Hi #{first_name}, thank you for your interest in #{forum_name}. #{link}"
    else
      link
    end
  end

  def invited_to_event_text
    "Hi #{first_name}, you're invited to #{event_name}! Please confirm you're coming: #{link}"
  end

  def invited_to_join_text
    "Hi #{first_name}, we'd love to have you join #{forum_name}. Interested? #{link}"
  end

  def first_name
    application.name.to_s.split.first || application.name
  end

  def event_name
    application.event&.title || "our event"
  end

  def forum_name
    application.forum.name
  end

  def link
    public_membership_application_url(application.token)
  end

  def whatsapp_url(message)
    digits = application.phone.to_s.gsub(/\D/, "")
    "https://wa.me/#{digits}?text=#{CGI.escape(message)}"
  end
end
