# Builds a click-to-chat (wa.me) WhatsApp link so a member can thank whoever
# referred them a lead that turned into real business. Mirrors EventWhatsappMessage.
class ReferralThanksWhatsappMessage
  def self.for(referral)
    new(referral).build
  end

  def initialize(referral)
    @referral = referral
  end

  def build
    message = text
    { text: message, url: whatsapp_url(message) }
  end

  private

  attr_reader :referral

  def text
    referral.thank_you_message.presence || default_text
  end

  def default_text
    "Hi #{first_name}! 🎉 Great news — the lead you sent me turned into real business. " \
    "Thank you so much for thinking of me, it really means a lot! 🙏\n\n— #{referred_user.full_name}"
  end

  def first_name
    referrer.first_name.presence || referrer.full_name
  end

  def referrer
    referral.referrer
  end

  def referred_user
    referral.referred_user
  end

  def whatsapp_url(message)
    digits = referrer.mobile.to_s.gsub(/\D/, "")
    "https://wa.me/#{digits}?text=#{CGI.escape(message)}"
  end
end
