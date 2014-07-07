module Logster
  class Configuration
    # authorize_callback
    # Type: Lambda
    # Params: request env
    # Returns: boolean - true if the user can view the logs.
    #
    # current_context
    # Type: Lambda
    # Params: request env, block
    # Must call the passed block. Use this to do any setup needed, e.g. switching databases.
    attr_accessor :authorize_callback, :current_context
    # subdirectory
    # Type: String
    # The subdirectory Logster is mounted under - must match the path in your routes.rb
    attr_accessor :subdirectory
    # group_errors
    # Type: Boolean
    # Whether or not similar errors should be grouped together
    attr_accessor :group_errors
  end
end
