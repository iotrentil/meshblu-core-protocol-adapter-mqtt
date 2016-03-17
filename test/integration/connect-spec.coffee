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
    beforeEach ->
      {port} = @sut.address()
      @client  = mqtt.connect("mqtt://localhost:#{port}")
      # @client  = mqtt.connect("mqtt://meshblu.octoblu.com:1883")

    it 'should reject the connection an error', (done) ->
      @client.on 'error', (error) =>
        expect(=> throw error).to.throw 'Connection refused: Bad username or password'
        done()
