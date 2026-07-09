# Builds a click-to-chat (wa.me) WhatsApp link inviting a guest to an event,
# with a personal RSVP link that stays open — the guest can flip their
# answer any time before the event. Mirrors MembershipWhatsappMessage.
class EventWhatsappMessage
  include Rails.application.routes.url_helpers

  def self.for(registration)
    new(registration).build
  end

  def initialize(registration)
    @registration = registration
  end

  def build
    message = text
    { text: message, url: whatsapp_url(message) }
  end

  private

  attr_reader :registration

  def text
    case registration.rsvp_status.to_sym
    when :invited
      "Hi #{first_name}, you're invited to #{event.title} on #{event_date}! Please confirm you're coming: #{link}"
    when :going
      "Hi #{first_name}, see you at #{event.title} on #{event_date}! #{link}"
    when :not_going
      "Hi #{first_name}, sorry you can't make #{event.title}. If that changes, you can update your RSVP here: #{link}"
    end
  end

  def first_name
    registration.guest_name.to_s.split.first || registration.guest_name
  end

  def event
    registration.event
  end

  def event_date
    event.starts_at.strftime("%B %d, %Y")
  end

  def link
    public_event_rsvp_url(registration.token)
  end

  def whatsapp_url(message)
    digits = registration.guest_phone.to_s.gsub(/\D/, "")
    "https://wa.me/#{digits}?text=#{CGI.escape(message)}"
  end
end
