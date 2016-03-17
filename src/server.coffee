mosca = require 'mosca'

class Server
  constructor: ({@port}) ->
  address: =>
    {address: '0.0.0.0', port: @port}

  authenticate: (client, username, password, callback) =>
    callback new Error('unauthorized')

  start: (callback) =>
    @server = mosca.Server {@port}

    @server.on 'ready', => @onReady callback
    @server.on 'clientConnected', @onConnect

  stop: (callback) =>
    @server.close callback

  onConnect: (client) =>
    console.log client

  onReady: (callback) =>
    @server.authenticate = @authenticate
    callback()

module.exports = Server
