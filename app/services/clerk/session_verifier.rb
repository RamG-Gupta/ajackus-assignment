require "jwt"

module Clerk
  class SessionVerifier
    class InvalidToken < StandardError; end

    def self.call(token)
      key = ENV["CLERK_JWT_KEY"]
      raise InvalidToken, "Clerk verification key is not configured" if key.blank?

      verification_key = OpenSSL::PKey.read(key)
      claims, = JWT.decode(token, verification_key, true, algorithm: "RS256", verify_expiration: true, verify_not_before: true)
      raise InvalidToken, "Token has no expiration" if claims["exp"].blank?

      verify_issuer!(claims)
      verify_party!(claims)
      user_id = claims["sub"]
      raise InvalidToken, "Token has no user subject" if user_id.blank?

      user_id
    rescue JWT::DecodeError, OpenSSL::PKey::PKeyError, JWT::ExpiredSignature, JWT::ImmatureSignature => e
      raise InvalidToken, e.message
    end

    def self.verify_issuer!(claims)
      issuer = ENV["CLERK_ISSUER"]
      return if issuer.blank? && !Rails.env.production?
      raise InvalidToken, "Clerk issuer is not configured" if issuer.blank?
      raise InvalidToken, "Invalid Clerk issuer" unless claims["iss"] == issuer
    end
    private_class_method :verify_issuer!

    def self.verify_party!(claims)
      parties = ENV.fetch("CLERK_AUTHORIZED_PARTIES", "").split(",").map(&:strip).reject(&:blank?)
      return if parties.empty? && !Rails.env.production?
      raise InvalidToken, "Clerk authorized parties are not configured" if parties.empty?
      raise InvalidToken, "Invalid Clerk authorized party" unless parties.include?(claims["azp"])
    end
    private_class_method :verify_party!
  end
end
