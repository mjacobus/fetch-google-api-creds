require 'sinatra'
require 'googleauth'
require 'google/apis/gmail_v1'
require 'dotenv/load'

set :port, 8080

SCOPES = ['https://www.googleapis.com/auth/gmail.readonly']
CREDENTIALS_PATH = 'credentials.json'

get '/' do
  'Gmail API App'
end

get '/authorize' do
  client_id = Google::Auth::ClientId.from_file(CREDENTIALS_PATH)
  token_store = Google::Auth::Stores::FileTokenStore.new(file: 'tokens.yaml')
  authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPES, token_store)
  user_id = 'default'
  credentials = authorizer.get_credentials(user_id)

  if credentials.nil?
    redirect authorizer.get_authorization_url(base_url: request.url)
  else
    'Credentials already authorized'
  end
end

get '/oauth2callback' do
  client_id = Google::Auth::ClientId.from_file(CREDENTIALS_PATH)
  token_store = Google::Auth::Stores::FileTokenStore.new(file: 'tokens.yaml')
  authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPES, token_store)
  user_id = 'default'
  credentials = authorizer.get_and_store_credentials_from_code(
    user_id:, code: params[:code], base_url: request.url
  )
  'Authorization complete'
end
