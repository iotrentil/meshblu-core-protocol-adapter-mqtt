Connection = require '../connection'

describe 'Receiving a message', ->
  beforeEach (done) ->
    @connection = new Connection
    @connection.connect (error, {@client, @redisClient}) =>
      return done error if error?
      done()

  afterEach (done) ->
    @connection.stopAll done

  describe 'when a message is sent', ->
    beforeEach (done) ->
      @client.on 'message', (fakeTopic, buffer) =>
        @mqttMessage = JSON.parse buffer.toString()
        done()

      @redisClient.publish 'received:u', '{"devices":["*"],"payload":"hi"}', (error) =>
        return done error if error?

    it 'should forward the message to the client', ->
      expect(@mqttMessage.topic).to.deep.equal 'message'
