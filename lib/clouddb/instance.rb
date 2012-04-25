module CloudDB
  class Instance
    
    attr_reader :id
    attr_reader :name
    attr_reader :hostname
    attr_reader :created
    attr_reader :udpated
    attr_reader :flavor_id
    attr_reader :volume_size
    attr_reader :status
    
    # Creates a new CloudDB::Instance object representing a Database instance.
    def initialize(connection,id)
      @connection    = connection
      @id            = id
      @dbmgmthost   = connection.dbmgmthost
      @dbmgmtpath   = connection.dbmgmtpath
      @dbmgmtport   = connection.dbmgmtport
      @dbmgmtscheme = connection.dbmgmtscheme
      populate
      self
    end
    
    # Updates the information about the current Instance object by making an API call.
    def populate
      response = @connection.dbreq("GET", @dbmgmthost, "#{@dbmgmtpath}/instances/#{CloudDB.escape(@id.to_s)}", @dbmgmtport, @dbmgmtscheme)
      CloudDB::Exception.raise_exception(response) unless response.code.to_s.match(/^20.$/)
      data = JSON.parse(response.body)['instance']
      @id          = data["id"]
      @name        = data["name"]
      @hostname    = data["hostname"]
      @created     = data["created"]
      @updated     = data["updated"]
      @flavor_id   = data["flavor"]["id"]
      @volume_size = data["volume"]["size"]
      @status      = data["status"]
      true
    end
    alias :refresh :populate

    # Enables the root user for the specified database instance and returns the root password.
    #
    #    >> i.enable_root
    def enable_root()
      response = @connection.dbreq("POST", @dbmgmthost, "#{@dbmgmtpath}/instances/#{CloudDB.escape(@id.to_s)}/root", @dbmgmtport, @dbmgmtscheme, {})
      CloudDB::Exception.raise_exception(response) unless response.code.to_s.match(/^20.$/)
      body = JSON.parse(response.body)['user']
      return body
    end

    # Returns true if root user is enabled for the specified database instance or false otherwise.
    #
    #    >> i.root_enabled?
    def root_enabled?()
      response = @connection.dbreq("GET", @dbmgmthost, "#{@dbmgmtpath}/instances/#{CloudDB.escape(@id.to_s)}/root", @dbmgmtport, @dbmgmtscheme, {})
      CloudDB::Exception.raise_exception(response) unless response.code.to_s.match(/^20.$/)
      is_enabled = JSON.parse(response.body)['rootEnabled']
      return is_enabled
    end

    # Lists the databases associated with this Instance
    #
    #    >> i.list_databases
    def list_databases
      response = @connection.dbreq("GET", @dbmgmthost, "#{@dbmgmtpath}/instances/#{CloudDB.escape(@id.to_s)}/databases", @dbmgmtport, @dbmgmtscheme)
      CloudDB::Exception.raise_exception(response) unless response.code.to_s.match(/^20.$/)
      CloudDB.symbolize_keys(JSON.parse(response.body)["databases"])
    end
    alias :databases :list_databases

    # Returns a CloudDB::Database object for the given database name.
    def get_database(name)
      CloudDB::Database.new(self, name)
    end
    alias :database :get_database

    # Creates a brand new database and associates it with the current Instance.
    #
    # Options:
    # :name - Specifies the database name for creating the database. *required*
    # :character_set - Set of symbols and encodings. The default character set is utf8.
    # :collate - Set of rules for comparing characters in a character set. The default value for collate is utf8_general_ci.
    def create_database(options={})
      body = Hash.new
      body[:name]           = options[:name] or raise CloudDB::Exception::MissingArgument, "Must provide a name to create a database"
      body[:character_set]  = options[:character_set] || 'utf8'
      body[:collate]        = options[:collate] || 'utf8_general_ci'
      (raise CloudDB::Exception::Syntax, "Database name must be 64 characters or less") if options[:name].size > 64

      response = @connection.dbreq("POST", @dbmgmthost, "#{@dbmgmtpath}/instances/#{CloudDB.escape(@id.to_s)}/databases", @dbmgmtport, @dbmgmtscheme, {}, body)
      CloudDB::Exception.raise_exception(response) unless response.code.to_s.match(/^20.$/)
      true
    end

    # Lists the users associated with this Instance
    #
    #    >> i.list_users
    def list_users
      response = @connection.dbreq("GET", @dbmgmthost, "#{@dbmgmtpath}/instances/#{CloudDB.escape(@id.to_s)}/users", @dbmgmtport, @dbmgmtscheme)
      CloudDB::Exception.raise_exception(response) unless response.code.to_s.match(/^20.$/)
      CloudDB.symbolize_keys(JSON.parse(response.body)["users"])
    end
    alias :users :list_users

    # Returns a CloudDB::User object for the given user name.
    def get_user(name)
      CloudDB::User.new(self, name)
    end
    alias :user :get_user

    # Creates a brand new user and associates it with the current instance. Returns the new User object.
    #
    # Options:
    # :name - Name of the user for the database(s). *required*
    # :password - User password for database access. *required*
    # :databases - An array of databases with at least one database. *required*
    def create_user(options={})
      body = Hash.new
      body[:name]       = options[:name] or raise CloudDB::Exception::MissingArgument, "Must provide a name for the user"
      body[:password]   = options[:password] or raise CloudDB::Exception::MissingArgument, "Must provide a password for the user"
      body[:databases]  = options[:databases]
      (raise CloudLB::Exception::Syntax, "Must provide at least one database in the :databases array") if (!options[:databases].is_a?(Array) || options[:databases].size < 1)

      response = @connection.dbreq("POST", @dbmgmthost, "#{@dbmgmtpath}/instances/#{CloudDB.escape(@id.to_s)}/users", @dbmgmtport, @dbmgmtscheme, {}, body)
      CloudDB::Exception.raise_exception(response) unless response.code.to_s.match(/^20.$/)
      true
    end

    # Deletes the current instance object.  Returns true if successful, raises an exception otherwise.
    def destroy!
      response = @connection.dbreq("DELETE", @dbmgmthost, "#{@dbmgmtpath}/instances/#{CloudDB.escape(@id.to_s)}", @dbmgmtport, @dbmgmtscheme)
      CloudDB::Exception.raise_exception(response) unless response.code.to_s.match(/^202$/)
      true
    end

  end
end
