class CheckpointV1 < Sinatra::Base
  get '/sessions/:key' do
    @identity = Identity.find(SessionManager.identity_id_for_session(params[:key]))
    check_god_credentials(@identity.realm_id)
    render :rabl, :identity, :format => :json
  end

  post '/sessions' do
    identity = Identity.find(params[:identity_id])
    check_god_credentials(identity.realm_id)
    expire = (params[:expire] == 'never') ? nil : (params[:expire].try(:to_i) || 1.hour)
    { session: SessionManager.new_session(identity.id, :expire => expire) }.to_json
  end

  delete '/sessions/:key' do
    identity = Identity.find(SessionManager.identity_id_for_session(params[:key]))
    check_god_credentials(identity.realm_id)
    SessionManager.kill_session(params[:key])
    { identity_id: identity.id }.to_json
  end
end
