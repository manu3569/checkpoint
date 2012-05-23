require 'ostruct'

class Realm < ActiveRecord::Base

  has_many :accounts
  has_many :identities
  has_many :domains
  belongs_to :primary_domain, :class_name => "Domain"

  validates_uniqueness_of :label, :allow_nil => false
  validates_each :label do |record, attr, value|
    record.errors.add(attr, "Realm name 'current' is reserved") if value == 'current'
  end

  def self.find_by_url(url)
    search_strings_for_url(url) do |domain|
      result = joins(:domains).where('domains.name = ?', domain).first
      return result if result
    end
  end

  def god_sessions
    Session.where("sessions.identity_id in (select id from identities where god and realm_id = ?)", id)
  end

  def external_service_keys
    keys = YAML.load(self.service_keys) if self.service_keys.present?
    raise "Missing or malformed configuration for #<Realm:#{id} #{label}>" unless keys
    keys
  end

  def keys_for(provider)
    OpenStruct.new(external_service_keys.fetch(provider))
  end

  private

  # Provided a block, this method will yield variations on the host with increasing 
  # specificity: 'foo.bar.example.com' will yield "example.com", "bar.example.com",
  # "foo.bar.example.com".
  def self.search_strings_for_url(url, &block)
    segments = url[/(?:https?\:\/\/)?([^\/]+)/,1].split('.') # extract the domain and split the subdomains
    candidate = [segments.pop]
    yield(candidate.unshift(segments.pop).join('.')) until segments.empty?
  end

end
