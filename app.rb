require 'sinatra'
require 'googleauth'
require 'google/apis/gmail_v1'
require 'dotenv/load'
require 'puma'
require 'googleauth/stores/file_token_store'

set :port, 8080

RELEVANT_SCOPES = {
  'Read Gmail' => 'https://www.googleapis.com/auth/gmail.readonly',
  'Send Email' => 'https://www.googleapis.com/auth/gmail.send',
  'Manage Drafts' => 'https://www.googleapis.com/auth/gmail.compose',
  'Modify Gmail' => 'https://www.googleapis.com/auth/gmail.modify',
  'Full Access' => 'https://www.googleapis.com/auth/gmail'
}

CREDENTIALS_PATH = 'var/secrets/google_client_secrets.json'
TOKEN_FILE = './var/secrets/token.yaml'

enable :sessions
set :session_secret, ENV.fetch('SESSION_SECRET') { SecureRandom.hex(64) }

get '/' do
  'Gmail API App'
end

get '/google/authorize' do
  erb :authorize
end

post '/google/authorize' do
  selected_scopes = params[:scopes]&.map { |scope| RELEVANT_SCOPES[scope] } || []
  session[:selected_scopes] = selected_scopes
  client_id = Google::Auth::ClientId.from_file(CREDENTIALS_PATH)
  token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_FILE)
  authorizer = Google::Auth::UserAuthorizer.new(client_id, selected_scopes, token_store)
  user_id = 'default'
  credentials = authorizer.get_credentials(user_id)

  if credentials.nil?
    redirect authorizer.get_authorization_url(base_url: request.url.gsub('/authorize', '/oauth2callback'))
  else
    'Credentials already authorized'
  end
end

get '/google/oauth2callback' do
  selected_scopes = session[:selected_scopes]
  client_id = Google::Auth::ClientId.from_file(CREDENTIALS_PATH)
  token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_FILE)
  authorizer = Google::Auth::UserAuthorizer.new(client_id, selected_scopes, token_store)
  user_id = 'default'
  credentials = authorizer.get_and_store_credentials_from_code(
    user_id:, code: params[:code], base_url: request.url.gsub('/oauth2callback', '/authorize')
  )
  'Authorization complete'
end

__END__

@@authorize
<!DOCTYPE html>
<html>
<head>
  <title>Authorize Gmail Scopes</title>
</head>
<body>
  <h1>Select Scopes to Authorize</h1>
  <form action="/google/authorize" method="post">
    <% RELEVANT_SCOPES.each do |name, scope| %>
      <div>
        <input type="checkbox" id="<%= name %>" name="scopes[]" value="<%= name %>">
        <label for="<%= name %>"><%= name %></label>
      </div>
    <% end %>
    <button type="submit">Authorize</button>
  </form>
</body>
</html>
