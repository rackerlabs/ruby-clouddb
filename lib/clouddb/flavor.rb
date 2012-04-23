module CloudDB
  class Flavor
    attr_reader :id
    attr_reader :name
    attr_reader :ram
    attr_reader :vcpus

    # Creates a new CloudDB::Flavor object representing a database flavor.
    def initialize(connection,id)
      @connection    = connection
      @id            = id
      @lbmgmthost   = connection.lbmgmthost
      @lbmgmtpath   = connection.lbmgmtpath
      @lbmgmtport   = connection.lbmgmtport
      @lbmgmtscheme = connection.lbmgmtscheme
      populate
      return self
    end

    # Updates the information about the current Flavor object by making an API call.
    def populate
      response = @connection.dbreq("GET",@lbmgmthost,"#{@lbmgmtpath}/flavors/#{CloudDB.escape(@id.to_s)}",@lbmgmtport,@lbmgmtscheme)
      CloudDB::Exception.raise_exception(response) unless response.code.to_s.match(/^20.$/)
      data = JSON.parse(response.body)['flavor']
      @id                    = data["id"]
      @name                  = data["name"]
      @ram                   = data["ram"]
      @vcpus                 = data["vcpus"]
      @links                 = data["links"]
      true
    end
    alias :refresh :populate

  end
end
