class CheckpointV1 < Sinatra::Base

  helpers do
    def create_identity(identity_data, account_data)
      attributes = identity_data || {}
      identity = Identity.create! attributes.merge(:realm => current_realm)

      if account_data
        attributes = account_data.merge(:realm => current_realm, :identity => identity)
        Account.create! attributes
        identity.ensure_primary_account
        identity.save!
      end
      identity
    end
  end

  # @apidoc
  # Create a new identity
  #
  # @note Only for gods. Check readme for details on the parameters.
  # @description Typically a new identity is created implicitly by logging in for the first
  #   time in a new realm. This endpoint is used for importing accounts from legacy systems.
  # @category Checkpoint/Identities
  # @path /api/checkpoint/v1/identities
  # @example /api/checkpoint/v1/identities
  # @http POST
  # @required [Hash] identity The attributes of the new identity
  # @required [Hash] account The attributes of the default account
  # @status 200 [JSON]

  post '/identities' do
    check_god_credentials(current_realm.id)

    identity = create_identity(params['identity'], params['account'])
    pg :identity, :locals => {:identity => identity}
  end

  # @apidoc
  # Update attributes for an identity
  #
  # @note Only for gods. Check readme for details on the parameters.
  # @category Checkpoint/Identities
  # @path /api/checkpoint/v1/identities/:id
  # @example /api/checkpoint/v1/identities/1337
  # @http POST
  # @required [Integer] id The id of the identity to update
  # @required [Hash] identity The updated attributes
  # @status 200 [JSON]

  put '/identities/:id' do |id|
    check_god_credentials(current_realm.id)
    identity = Identity.find(id)
    identity.update_attributes!(params[:identity])
    pg :identity, :locals => {:identity => identity}
  end


  # @apidoc
  # Retrieve one or more identities including profiles
  #
  # @category Checkpoint/Identities
  # @path /api/checkpoint/v1/identities/:id
  # @example /api/checkpoint/v1/identities/me
  # @http GET
  # @required [Integer] id The identity id or a comma-separated list of ids, 'me'
  #   for current user
  # @status 200 [JSON]

  get '/identities/:id' do |id|
    if id =~ /\,/
      # Retrieve a list of identities      
      ids = id.split(/\s*,\s*/).compact
      identities = Identity.cached_find_all_by_id(ids)
      pg :identities, :locals => {:identities => identities}
    else
      # Retrieve a single identity
      identity = (id == 'me') ? current_identity : Identity.cached_find_by_id(id)
      halt 200, {'Content-Type' => 'application/json'}, "{}" unless identity
      pg :identity, :locals => {:identity => identity}
    end
  end

end
