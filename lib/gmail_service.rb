require 'googleauth'
require 'google/apis/gmail_v1'
require 'googleauth/stores/file_token_store'

class GmailService
  CREDENTIALS_PATH = 'var/secrets/google_client_secrets.json'
  TOKEN_FILE = 'var/secrets/token.yaml'
  SCOPE = 'https://www.googleapis.com/auth/gmail.readonly'

  def initialize
    client_id = Google::Auth::ClientId.from_file(CREDENTIALS_PATH)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_FILE)
    authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
    user_id = 'default'
    @credentials = authorizer.get_credentials(user_id)
    @service = Google::Apis::GmailV1::GmailService.new
    @service.authorization = @credentials
  end

  def search_emails(subject:, sender:)
    query = "subject:#{subject} from:#{sender}"
    result = @service.list_user_messages('me', q: query)
    messages = result.messages || []

    emails = messages.map do |message|
      msg = @service.get_user_message('me', message.id)
      {
        id: msg.id,
        snippet: msg.snippet,
        subject: msg.payload.headers.find { |h| h.name == 'Subject' }&.value,
        from: msg.payload.headers.find { |h| h.name == 'From' }&.value,
        date: msg.payload.headers.find { |h| h.name == 'Date' }&.value
      }
    end

    emails
  end

  def fetch_email(id)
    msg = @service.get_user_message('me', id)
    msg.to_h # Convert the message to a hash, which will be converted to JSON in the Sinatra route
  end
end
