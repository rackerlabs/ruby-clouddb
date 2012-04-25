module CloudDB
  class User

    attr_reader :name

    # Creates a new CloudDB::User object representing a database.
    def initialize(instance, name)
      @connection     = instance.connection
      @instance       = instance
      @name           = name
      @dbmgmthost     = @connection.dbmgmthost
      @dbmgmtpath     = @connection.dbmgmtpath
      @dbmgmtport     = @connection.dbmgmtport
      @dbmgmtscheme   = @connection.dbmgmtscheme
      self
    end

    # Deletes the current User object and removes it from the instance. Returns true if successful, raises an exception if not.
    def destroy!
      response = @connection.dbreq("DELETE",@dbmgmthost,"#{@dbmgmtpath}/instances/#{CloudDB.escape(@instance.id.to_s)}/users/#{CloudDB.escape(@name.to_s)}",@dbmgmtport,@dbmgmtscheme)
      CloudDB::Exception.raise_exception(response) unless response.code.to_s.match(/^20.$/)
      true
    end

  end
end