require 'uri'
require 'simpleidn'
require 'timeout'
require 'socket'

require_relative '../domain_name_validator'

# Represents either a DNS domain name or an IP address.
class Domain < ActiveRecord::Base

  belongs_to :realm
  has_one :primary_realm,
    :class_name => 'Realm',
    :foreign_key => :primary_domain_id,
    :dependent => :nullify

  after_save :ensure_primary_domain

  ts_vector :origins

  validates_with ::DomainNameValidator
  validates :name, :presence => {}, :uniqueness => {}

  def allow_origin?(origin)
    # First check if the origin resolves to same realm as self
    origin_domain = Domain.resolve_from_host_name(origin)
    return true if origin_domain && origin_domain.realm == self.realm
    # Did not, then check if it is explicitly listed as a valid origin
    all_hosts =  (realm.domains.map(&:name) << self.origins.to_a).compact.flatten.uniq
    all_hosts.include?(SimpleIDN.to_ascii(origin))
  end

  def add_origin(origin)
    raise "Invalid origin #{origin}" unless DomainNameValidator.valid_name_or_ip?(origin)
    self.origins = self.origins << SimpleIDN.to_ascii(origin)
    save!
  end

  def remove_origin(origin)
    origin_host = SimpleIDN.to_ascii(origin)
    if self.origins.include?(origin_host)
      self.origins = self.origins.to_a.select { |d| d != origin_host }
      save
    else
      raise "Not found"
    end
  end

  class << self

    # Finds domain matching a host name or its IP address.
    def resolve_from_host_name(host_name)
      if DomainNameValidator.ip_address?(host_name)
        domain = where(name: host_name).first
      else
        domain = where(%{
          case
            when name like '%*%' then
              (name = :name or :name like regexp_replace(name, E'\\\\*', '%', 'g'))
            else
              name = :name
          end
        }, {name: host_name}).first

        if not domain and (ips = resolve_name_to_ips(host_name))
          domain ||= where(name: ips).first
        end
      end
      domain
    end

    private

      def resolve_name_to_ips(host_name)
        begin
          timeout(4) do
            begin
              ips = TCPSocket.gethostbyname(SimpleIDN.to_ascii(host_name))
              ips.select! { |s| s.is_a?(String) && DomainNameValidator.ip_address?(s) }
              return ips if ips.any?
            rescue SocketError => e
              logger.error("Socket error resolving #{host_name}")
            end
          end
        rescue Timeout::Error => e
          logger.error("Timeout resolving #{host_name} via DNS")
        end
        nil
      end

  end

  def name=(name)
    if name
      super(name.gsub(/\s/, '').downcase)
    else
      super(nil)
    end
  end

  private

    def ensure_primary_domain
      if self.realm and not self.realm.primary_domain
        self.realm.primary_domain = self
        self.realm.save!
      end
      nil
    end

end
