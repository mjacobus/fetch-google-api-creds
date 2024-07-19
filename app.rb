require 'sinatra'
require 'googleauth'
require 'google/apis/gmail_v1'
require 'dotenv/load'
require 'puma'
require 'googleauth/stores/file_token_store'
require_relative 'lib/gmail_service'

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

get '/google/fetch_emails' do
  erb :fetch_emails
end

post '/google/fetch_emails' do
  subject = params[:subject]
  sender = params[:sender]

  gmail_service = GmailService.new
  emails = gmail_service.search_emails(subject:, sender:)

  erb :display_emails, locals: { emails: }
end

get '/google/fetch_email/:id' do
  gmail_service = GmailService.new
  email = gmail_service.fetch_email(params[:id])
  content_type :json
  email.to_json
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

@@fetch_emails
<!DOCTYPE html>
<html>
<head>
  <title>Fetch Emails</title>
</head>
<body>
  <h1>Fetch Emails</h1>
  <form action="/google/fetch_emails" method="post">
    <div>
      <label for="subject">Subject:</label>
      <input type="text" id="subject" name="subject">
    </div>
    <div>
      <label for="sender">Sender:</label>
      <input type="text" id="sender" name="sender">
    </div>
    <button type="submit">Fetch Emails</button>
  </form>
</body>
</html>

@@display_emails
<!DOCTYPE html>
<html>
<head>
  <title>Fetched Emails</title>
</head>
<body>
  <h1>Fetched Emails</h1>
  <ul>
    <% emails.each do |email| %>
      <li>
        <p><strong>ID:</strong> <%= email[:id] %></p>
        <p><strong>Snippet:</strong> <%= email[:snippet] %></p>
        <p><strong>Subject:</strong> <%= email[:subject] %></p>
        <p><strong>From:</strong> <%= email[:from] %></p>
        <p><strong>Date:</strong> <%= email[:date] %></p>
        <p><a href="/google/fetch_email/<%= email[:id] %>">View Full Email</a></p>
      </li>
    <% end %>
  </ul>
  <p><a href="/google/fetch_emails">Back</a></p>
</body>
</html>
