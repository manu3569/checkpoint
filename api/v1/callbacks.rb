class CheckpointV1 < Sinatra::Base

  # @apidoc
  # Perform all relevant callbacks checking if the provided action is allowed for the current
  # identity. The vertict is returned in the 'allowed' parameter. If the action is disallowed
  # the reason is provided in the 'reason' field and the url of the denying callback will be in
  # the 'url'-field.
  #
  # @category Checkpoint/Callbacks
  # @path /api/checkpoint/v1/callbacks/allowed/:method/:uid
  # @http GET
  # @example /api/checkpoint/v1/callbacks/allowed/create/post.blog:acme.blog
  # @required [String] method One of 'create', 'update', 'delete'
  # @required [String] uid The uid of the object in question
  # @optional [Integer] identity Ask for a specific identity (default: current identity)
  # @optional [String] * Any other parameter provided will be forwarded to each callback for its consideration
  # @status 200 Result hash
  # @status 500 One or more of the callbacks failed, please call again later

  get "/callbacks/allowed/:method/:uid" do
    params[:identity] ||= current_identity.try(:id)
    params.delete('splat')
    params.delete('captures')
    if banned_path = Banning.banned?(params.to_options)
      pg :callback_result, :locals => {:allowed => false, :url => request.url,
        :reason => "This identity is banned from '#{banned_path}'."}
    else
      allowed, url, reason = Callback.allow?(params.to_options)
      pg :callback_result, :locals => {:allowed => allowed, :url => url, :reason => reason}
    end
  end

  # @apidoc
  # Get all callbacks for the current realm. Requires god permissions.
  #
  # @category Checkpoint/Callbacks
  # @path /api/checkpoint/v1/callbacks
  # @http GET
  # @example /api/checkpoint/v1/callbacks
  # @status 200 [Collection of callbacks]
  # @status 403 You are not god

  get "/callbacks" do
    check_god_credentials
    pg :callbacks, :locals => {:callbacks => Callback.order('callbacks.id desc').of_realm(current_realm)}
  end

  # @apidoc
  # Get a specific callback. Requires god permissions.
  #
  # @category Checkpoint/Callbacks
  # @path /api/checkpoint/v1/callbacks/:id
  # @http GET
  # @example /api/checkpoint/v1/callbacks/1
  # @status 200 [Attributes of callback]
  # @status 403 You are not god

  get "/callbacks/:id" do
    callback = Callback.find(params[:id])
    check_god_credentials(callback.realm.id)
    pg :callback, :locals => { :callback => callback }
  end

  # @apidoc
  # Create a callback. Requires god permissions.
  #
  # @category Checkpoint/Callbacks
  # @path /api/checkpoint/v1/callbacks
  # @http POST
  # @example /api/checkpoint/v1/callbacks
  # @required [String] callback.path The path the callback shall protect
  # @required [String] callback.url The url to be notified
  # @status 201 [Attributes of callback]
  # @status 403 You are not god
  # @status 404 No such realm
  # @status 400 You forgot to namespace your record - or, there were no attributes

  post "/callbacks" do
    attributes = params[:callback]
    halt 400, "Please remember to namespace your records" if attributes.nil?
    realm_label = attributes[:path].split('.').first
    realm = Realm.find_by_label(realm_label)
    halt 404, "No such realm (#{realm_label})" unless realm
    check_god_credentials(realm.id)
    callback = Callback.create!(
      :path => attributes[:path],
      :url => attributes[:url])
    [201, pg(:callback, :locals => { :callback => callback })]
  end

  # @apidoc
  # Delete a specific callback. Requires god permissions.
  #
  # @category Checkpoint/Callbacks
  # @path /api/checkpoint/v1/callbacks/:id
  # @http DELETE
  # @example /api/checkpoint/v1/callbacks/1
  # @status 200 [Attributes of former callback]
  # @status 403 You are not god

  delete "/callbacks/:id" do
    callback = Callback.find(params[:id])
    check_god_credentials(callback.realm.id)
    callback.destroy
    pg :callback, :locals => { :callback => callback }
  end
end