require 'uri'

class CheckpointV1 < Sinatra::Base

  helpers do
    def parse_url(url)
      parsed = URI.parse(url)
      parsed.host ||= request.host
      parsed.scheme ||= request.scheme
      parsed.port ||= request.port
      parsed
    rescue URI::InvalidURIError
      halt 400, "Invalid URL #{url.inspect}"
    end

    # Checks that the provided host-name is attached to the current realm
    def check_domain_is_within_current_realm(domain_name)
      domain = Domain.resolve_from_host_name(domain_name)
      halt 403, "No realm configured for domain #{domain_name}" unless domain
      halt 400, "No origin realm for #{request.host}" unless current_realm
      halt 403, "#{domain_name} is not attached to the realm '#{current_realm.label}'." unless domain.realm_id == current_realm.id
      true
    end
  end

  # @apidoc
  # Redirect safely to any domain within the realm while preserving the session.
  #
  # @note This is an endpoint for browsers.
  # @description Requires that both the origin domain and target domain is attached to the same
  #   realm. This method falls back to a common redirect if the origin and target domain
  #   is the same. To transfer session from 'acme.no' to an url on 'acme-other-place.org' you would 
  #   direct the user to an url like this:
  #   'http://acme.no/api/v1/checkpoint/transfer?target_url=http%3A%2F%2Facme-other-place.org'
  # @category Checkpoint/Transfer
  # @path /api/checkpoint/v1/transfer
  # @http GET
  # @required [Integer] target_url The full url (including host name) to redirect the user.
  # @status 301 Redirect.

  get '/transfer' do
    target_url = parse_url(params[:target])

    # Are we leaving or arriving?
    if (request.host != target_url.host)
      # We are leaving the origin domain.
      check_domain_is_within_current_realm(target_url.host)

      new_url = target_url.dup
      new_url.path = '/api/checkpoint/v1/transfer'
      redirect url_with_query_params(new_url.to_s,
        :target => target_url.to_s,
        :session => current_session.try(:key))
    else
      # We have arrived at the target domain.
      set_session_key(params[:session]) if params[:session]
      redirect target_url.to_s
    end
  end

  get '/fetch_session' do
    target_url = parse_url(params[:target])
    check_domain_is_within_current_realm(target_url.host)
    redirect url_with_query_params("#{request.scheme}://#{current_realm.primary_domain.name}/api/checkpoint/v1/transfer",
      :target => target_url)
  end

end