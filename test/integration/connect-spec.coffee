mqtt       = require 'mqtt'
portfinder = require 'portfinder'
Server     = require '../../src/server'

describe 'Connecting to the server', ->
  beforeEach (done) ->
    portfinder.getPort (error, port) =>
      return done error if error?
      @sut = new Server {port}
      @sut.start done

  afterEach (done) ->
    @sut.stop done

  describe 'when a generic, anonymous mqtt client connects', ->
    it 'should connect', (done) ->
      {port} = @sut.address()
      @client  = mqtt.connect("mqtt://localhost:#{port}")
      @client.on 'connect', => done()
