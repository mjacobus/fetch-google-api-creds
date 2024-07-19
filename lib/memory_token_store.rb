require 'googleauth/token_store'

class MemoryTokenStore < Google::Auth::TokenStore
  def initialize(session)
    @session = session
  end

  def load(id)
    @session[id]
  end

  def store(id, token)
    @session[id] = token
  end

  def delete(id)
    @session.delete(id)
  end
end
