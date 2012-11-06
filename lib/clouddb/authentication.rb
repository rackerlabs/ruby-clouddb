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
        :headers                       => { "X-Auth-User" => connection.authuser, "X-Auth-Key" => connection.authkey, "User-Agent" => "Cloud Databases Ruby API #{VERSION}" },
        :verbose                       => ENV['DATABASES_VERBOSE'] ? true : false)
      CloudDB.hydra.queue(request)
      CloudDB.hydra.run
      response = request.response
      headers = response.headers_hash
      if (response.code.to_s == "204")
        connection.authtoken = headers["X-Auth-Token"]
        user_id = headers["X-Server-Management-Url"].match(/.*\/(\d+)$/)[1]
        headers["X-Server-Management-Url"] = "https://#{connection.region}.databases.api.rackspacecloud.com/v1.0/#{user_id}"
        connection.dbmgmthost = URI.parse(headers["X-Server-Management-Url"]).host
        connection.dbmgmtpath = URI.parse(headers["X-Server-Management-Url"]).path.chomp
        # Force the path into the v1.0 URL space
        connection.dbmgmtpath.sub!(/\/.*?\//, '/v1.0/')
        connection.dbmgmtport = URI.parse(headers["X-Server-Management-Url"]).port
        connection.dbmgmtscheme = URI.parse(headers["X-Server-Management-Url"]).scheme
        connection.authok = true
      else
        connection.authtoken = false
        raise CloudDB::Exception::Authentication, "Authentication failed with response code #{response.code}"
      end
    end
  end
end
