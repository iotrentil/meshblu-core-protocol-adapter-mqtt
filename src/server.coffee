mosca = require 'mosca'

class Server
  constructor: ({@port}) ->
  address: =>
    {address: '0.0.0.0', port: @port}

  start: (callback) =>
    @server = mosca.Server {@port}
    @server.on 'ready', callback

  stop: (callback) =>
    @server.close callback

module.exports = Server
