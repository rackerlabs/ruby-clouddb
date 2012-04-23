module CloudDB
  class Authentication
    
    # Performs an authentication to the Rackspace Cloud authorization servers.  Opens a new HTTP connection to the API server,
    # sends the credentials, and looks for a successful authentication.  If it succeeds, it sets the svrmgmthost,
    # svrmgtpath, svrmgmtport, svrmgmtscheme, authtoken, and authok variables on the connection.  If it fails, it raises
    # an exception.
    #
    # Should probably never be called directly.
    def initialize(connection)
      request = Typhoeus::Request.new(connection.auth_url,
        :method                        => :get,
        :headers                       => { "X-Auth-User" => connection.authuser, "X-Auth-Key" => connection.authkey },
        :user_agent                    => "Cloud Databases Ruby API #{VERSION}",
        :verbose                       => ENV['DATABASES_VERBOSE'] ? true : false)
      CloudDB.hydra.queue(request)
      CloudDB.hydra.run
      response = request.response
      headers = response.headers_hash
      if (response.code.to_s == "204")
        connection.authtoken = headers["x-auth-token"]
        user_id = headers["x-server-management-url"].match(/.*\/(\d+)$/)[1]
        headers["x-server-management-url"] = "https://#{connection.region}.databases.api.rackspacecloud.com/v1.0/#{user_id}"
        connection.lbmgmthost = URI.parse(headers["x-server-management-url"]).host
        connection.lbmgmtpath = URI.parse(headers["x-server-management-url"]).path.chomp
        # Force the path into the v1.0 URL space
        connection.lbmgmtpath.sub!(/\/.*?\//, '/v1.0/')
        connection.lbmgmtport = URI.parse(headers["x-server-management-url"]).port
        connection.lbmgmtscheme = URI.parse(headers["x-server-management-url"]).scheme
        connection.authok = true
      else
        connection.authtoken = false
        raise CloudDB::Exception::Authentication, "Authentication failed with response code #{response.code}"
      end
    end
  end
end
