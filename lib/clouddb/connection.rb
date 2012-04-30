module CloudDB
  class Connection

    attr_reader   :authuser
    attr_reader   :authkey
    attr_accessor :authtoken
    attr_accessor :authok
    attr_accessor :dbmgmthost
    attr_accessor :dbmgmtpath
    attr_accessor :dbmgmtport
    attr_accessor :dbmgmtscheme
    attr_reader   :auth_url
    attr_reader   :region

    # Creates a new CloudDB::Connection object.  Uses CloudDB::Authentication to perform the login for the connection.
    #
    # Setting the retry_auth option to false will cause an exception to be thrown if your authorization token expires.
    # Otherwise, it will attempt to re-authenticate.
    #
    # This will likely be the base class for most operations.
    #
    # The constructor takes a hash of options, including:
    #   :username - Your Rackspace Cloud username *required*
    #   :api_key - Your Rackspace Cloud API key *required*
    #   :region - The region in which to manage database instances. Current options are :dfw (Rackspace Dallas/Ft. Worth
    #             Datacenter), :ord (Rackspace Chicago Datacenter) and :lon (Rackspace London Datacenter). *required*
    #   :auth_url - The URL to use for authentication.  (defaults to Rackspace USA).
    #   :retry_auth - Whether to retry if your auth token expires (defaults to true)
    #
    # Example:
    #   dbaas = CloudDB::Connection.new(:username => 'YOUR_USERNAME', :api_key => 'YOUR_API_KEY', :region => :dfw)
    def initialize(options = {:retry_auth => true})
      @authuser = options[:username] || (raise CloudDB::Exception::Authentication, "Must supply a :username")
      @authkey = options[:api_key] || (raise CloudDB::Exception::Authentication, "Must supply an :api_key")
      @region = options[:region] || (raise CloudDB::Exception::Authentication, "Must supply a :region")
      @retry_auth = options[:retry_auth]
      @auth_url = options[:auth_url] || CloudDB::AUTH_USA
      @snet = ENV['RACKSPACE_SERVICENET'] || options[:snet]
      @authok = false
      @http = {}
      CloudDB::Authentication.new(self)
    end

    # Returns true if the authentication was successful and returns false otherwise.
    #
    # Example:
    #   dbaas.authok?
    #   => true
    def authok?
      @authok
    end

    # Returns the list of available database instances.
    #
    # Information returned includes:
    #   :id - The numeric id of the instance.
    #   :name - The name of the instance.
    #   :status - The current state of the instance (BUILD, ACTIVE, BLOCKED, RESIZE, SHUTDOWN, FAILED).
    def list_instances()
      response = dbreq("GET", dbmgmthost, "#{dbmgmtpath}/instances", dbmgmtport, dbmgmtscheme)
      CloudDB::Exception.raise_exception(response) unless response.code.to_s.match(/^20.$/)
      instances = CloudDB.symbolize_keys(JSON.parse(response.body)["instances"])
      return instances
    end
    alias :instances :list_instances

    # Returns the list of available database instances with detail.
    #
    # Information returned includes:
    #   :id - The numeric ID of the instance.
    #   :name - The name of the instance.
    #   :status - The current state of the instance (BUILD, ACTIVE, BLOCKED, RESIZE, SHUTDOWN, FAILED).
    #   :hostname - A DNS-resolvable hostname associated with the database instance.
    #   :flavor - The flavor of the instance.
    #   :volume - The volume size of the instance.
    #   :created - The time when the instance was created.
    #   :updated - The time when the instance was last updated.
    def list_instances_detail()
      response = dbreq("GET", dbmgmthost, "#{dbmgmtpath}/instances/detail", dbmgmtport, dbmgmtscheme)
      CloudDB::Exception.raise_exception(response) unless response.code.to_s.match(/^20.$/)
      instances = CloudDB.symbolize_keys(JSON.parse(response.body)["instances"])
      return instances
    end
    alias :instances_detail :list_instances_detail

    # Returns a CloudDB::Instance object for the given instance ID number.
    #
    # Example:
    #   dbaas.get_instance(692d8418-7a8f-47f1-8060-59846c6e024f)
    def get_instance(id)
      CloudDB::Instance.new(self,id)
    end
    alias :instance :get_instance

    # Creates a brand new database instance under your account.
    #
    # Options:
    #   :flavor_ref - reference to a flavor as specified in the response from the List Flavors API call. *required*
    #   :name - the name of the database instance.  Limited to 128 characters or less. *required*
    #   :size - specifies the volume size in gigabytes (GB). The value specified must be between 1 and 10. *required*
    #   :databases - the databases to be created for the instance.
    #   :users - the users to be created for the instance.
    #
    # Example:
    #   i = dbaas.create_instance(:flavor_ref => "https://ord.databases.api.rackspacecloud.com/v1.0/1234/flavors/1",
    #                             :name => "test_instance",
    #                             :volume => {:size => "1"},
    #                             :databases => [{:name => "testdb"}],
    #                             :users => [{:name => "test",
    #                                         :password => "test",
    #                                         :databases => [{:name => "testdb"}]}
    #                                       ]
    #                            )
    def create_instance(options = {})
      body = Hash.new
      body[:instance] = Hash.new

      body[:instance][:flavorRef]  = options[:flavor_ref] or raise CloudDB::Exception::MissingArgument, "Must provide a flavor to create an instance"
      body[:instance][:name]       = options[:name] or raise CloudDB::Exception::MissingArgument, "Must provide a name to create an instance"
      body[:instance][:volume]     = options[:volume] or raise CloudDB::Exception::MissingArgument, "Must provide a size to create an instance"
      body[:instance][:databases]  = options[:databases] if options[:databases]
      body[:instance][:users]      = options[:users] if options[:users]
      (raise CloudDB::Exception::Syntax, "Instance name must be 128 characters or less") if options[:name].size > 128

      response = dbreq("POST", dbmgmthost, "#{dbmgmtpath}/instances", dbmgmtport, dbmgmtscheme, {}, body.to_json)
      CloudDB::Exception.raise_exception(response) unless response.code.to_s.match(/^20.$/)
      body = JSON.parse(response.body)['instance']
      return get_instance(body["id"])
    end

    # Returns the list of available database flavors.
    #
    # Information returned includes:
    #   :id - The numeric id of this flavor
    #   :name - The name of the flavor
    #   :links - Useful information regarding the flavor
    def list_flavors()
      response = dbreq("GET", dbmgmthost, "#{dbmgmtpath}/flavors", dbmgmtport, dbmgmtscheme)
      CloudDB::Exception.raise_exception(response) unless response.code.to_s.match(/^20.$/)
      flavors = CloudDB.symbolize_keys(JSON.parse(response.body)["flavors"])
      return flavors
    end
    alias :flavors :list_flavors

    # Returns the list of available database flavors in detail.
    #
    # Information returned includes:
    #   :id - The numeric id of this flavor
    #   :name - The name of the flavor
    #   :vcpus - The amount of virtual cpu power
    #   :ram - The available memory in MB
    #   :links - Useful information regarding the flavor
    def list_flavors_detail()
      response = dbreq("GET", dbmgmthost, "#{dbmgmtpath}/flavors/detail", dbmgmtport, dbmgmtscheme)
      CloudDB::Exception.raise_exception(response) unless response.code.to_s.match(/^20.$/)
      flavors = CloudDB.symbolize_keys(JSON.parse(response.body)["flavors"])
      return flavors
    end
    alias :flavors_detail :list_flavors_detail

    # Returns a CloudDB::Flavor object for the given flavor id number.
    #
    # Example:
    #   dbaas.get_flavor(3)
    def get_flavor(id)
      CloudDB::Flavor.new(self,id)
    end
    alias :flavor :get_flavor

    # This method actually makes the HTTP REST calls out to the server. Relies on the thread-safe typhoeus
    # gem to do the heavy lifting.  Never called directly.
    def dbreq(method, server, path, port, scheme, headers = {}, data = nil, attempts = 0) # :nodoc:
      if data
        unless data.is_a?(IO)
          headers['Content-Length'] = data.respond_to?(:lstat) ? data.stat.size : data.size
        end
      else
        headers['Content-Length'] = 0
      end
      hdrhash = headerprep(headers)
      url = "#{scheme}://#{server}#{path}"
      print "DEBUG: Data is #{data}\n" if (data && ENV['DATABASES_VERBOSE'])
      request = Typhoeus::Request.new(url,
                                      :body          => data,
                                      :method        => method.downcase.to_sym,
                                      :headers       => hdrhash,
                                      :verbose       => ENV['DATABASES_VERBOSE'] ? true : false)
      CloudDB.hydra.queue(request)
      CloudDB.hydra.run

      response = request.response
      print "DEBUG: Body is #{response.body}\n" if ENV['DATABASES_VERBOSE']
      raise CloudDB::Exception::ExpiredAuthToken if response.code.to_s == "401"
      response
    rescue Errno::EPIPE, Errno::EINVAL, EOFError
      # Server closed the connection, retry
      raise CloudDB::Exception::Connection, "Unable to reconnect to #{server} after #{attempts} attempts" if attempts >= 5
      attempts += 1
      @http[server].finish if @http[server].started?
      start_http(server,path,port,scheme,headers)
      retry
    rescue CloudDB::Exception::ExpiredAuthToken
      raise CloudDB::Exception::Connection, "Authentication token expired and you have requested not to retry" if @retry_auth == false
      CloudDB::Authentication.new(self)
      retry
    end


    private

    # Sets up standard HTTP headers
    def headerprep(headers = {}) # :nodoc:
      default_headers = {}
      default_headers["X-Auth-Token"] = @authtoken if (authok? && @account.nil?)
      default_headers["X-Storage-Token"] = @authtoken if (authok? && !@account.nil?)
      default_headers["Connection"] = "Keep-Alive"
      default_headers["Accept"] = "application/json"
      default_headers["Content-Type"] = "application/json"
      default_headers["User-Agent"] = "Cloud Databases Ruby API #{CloudDB::VERSION}"
      default_headers.merge(headers)
    end

  end
end
