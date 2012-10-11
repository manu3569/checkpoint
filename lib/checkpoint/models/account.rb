class Account < ActiveRecord::Base

  class InUseError < Exception; end

  belongs_to :identity
  belongs_to :realm

  after_destroy :update_identity_primary_account
  
  after_save :invalidate_cache
  after_save lambda {
    self.identity.update_fingerprints_from_account!(self) if self.identity
  }
  before_destroy :invalidate_cache

  validates_presence_of :uid, :provider, :realm_id

  class << self
    # Creates or updates an account from auth data as provided by
    # omniauth. An existing identity or a realm must be provided
    # see https://github.com/intridea/omniauth/wiki/Auth-Hash-Schema for an overview of the data omniauth provides
    # in the options. E.g.:
    #     Account.declare_with_omniauth(auth, :realm => current_realm) # creates a new user
    #     Account.declare_with_omniauth(auth, :identity => current_identity) # attaches an account to an existing identity
    # If the account was previously attached to an identity, an InUseError exception will be raised.
    def declare_with_omniauth(auth_data, options = {})
      identity = options[:identity]      
      raise ArgumentError, "Identity or realm must be specified" unless (options[:realm] || identity)

      attributes = {
        :provider => auth_data['provider'],
        :uid => auth_data['uid'],
        :realm_id => options[:realm].try(:id) || identity.realm.id,
      }

      account = find_by_provider_and_realm_id_and_uid(attributes[:provider], attributes[:realm_id], attributes[:uid])

      identity = nil if identity.try(:provisional?) # toss the provisional identity

      identity ||= account.try(:identity) || Identity.create!(:realm => options[:realm])

      if account && account.identity != identity
        raise Account::InUseError.new('This account is already bound to a different identity.')
      end

      account ||= new(attributes)
      account.attributes = {
        :identity =>     identity,
        :token =>        auth_data['credentials']['token'],
        :secret =>       auth_data['credentials']['secret'],
        :nickname =>     auth_data['info']['nickname'],
        :name =>         auth_data['info']['name'],
        :location =>     auth_data['info']['location'],
        :image_url =>    auth_data['info']['image'],
        :description =>  auth_data['info']['description'],
        :email =>        auth_data['info']['email'],
        :profile_url =>  (auth_data['info']['urls'] || {})['Twitter']
      }
      account.save!

      identity.ensure_primary_account
      identity.save!

      account
    end
  end

  def authorized?
    !!credentials
  end

  def primary?
    identity.try(:primary_account_id) == self.id
  end

  def credentials
    return nil unless token && secret
    {:token => token, :secret => secret}
  end

  # Computes one or more hashes of the permanent components of the account 
  # data, which can function as a fingerprint to recognize future duplicate
  # accounts. This makes it possible to ban accounts purely based on
  # fingerprints.
  def fingerprints
    # Note: Fingerprints must always be lowercase due to current limitations in 
    # ar-tsvectors and Postgres indexing.
    digest = Digest::SHA256.new
    digest.update(self.provider.to_s)
    digest.update(self.uid.to_s)
    [digest.digest.unpack("H*")[0].hex.to_s(36)]
  end

  private

  def update_identity_primary_account
    return unless self.primary?
    self.identity.primary_account = nil
    self.identity.ensure_primary_account
    self.identity.save!
  end

  def invalidate_cache
    self.identity.invalidate_cache if self.identity
  end

end
