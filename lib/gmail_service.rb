require 'googleauth'
require 'google/apis/gmail_v1'
require 'json'

class GmailService
  SCOPE = 'https://www.googleapis.com/auth/gmail.readonly'

  def initialize(credentials_json)
    @credentials = Google::Auth::UserRefreshCredentials.make_creds(json_key_io: StringIO.new(credentials_json),
                                                                   scope: SCOPE)
    @service = Google::Apis::GmailV1::GmailService.new
    @service.authorization = @credentials
  end

  def search_emails(subject:, sender:)
    query = "subject:#{subject} from:#{sender}"
    result = @service.list_user_messages('me', q: query)
    messages = result.messages || []

    messages.map do |message|
      msg = @service.get_user_message('me', message.id)
      {
        id: msg.id,
        snippet: msg.snippet,
        subject: msg.payload.headers.find { |h| h.name == 'Subject' }&.value,
        from: msg.payload.headers.find { |h| h.name == 'From' }&.value,
        date: msg.payload.headers.find { |h| h.name == 'Date' }&.value
      }
    end
  end

  def fetch_email(id)
    msg = @service.get_user_message('me', id)
    msg.to_h # Convert the message to a hash, which will be converted to JSON in the Sinatra route
  end
end
