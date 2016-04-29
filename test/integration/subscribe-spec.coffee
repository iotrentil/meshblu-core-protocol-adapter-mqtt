Connection = require '../connection'

describe 'Subscribing to messages', ->
  beforeEach (done) ->
    @connection = new Connection
    @connection.connect (error, {@client, @jobManager, @redisClient}) =>
      return done error if error?
      done()

  afterEach (done) ->
    @connection.stopAll done

  describe 'when making a subscription', ->
    beforeEach (done) ->
      @client.subscribe 'u2'
      @jobManager.getRequest ['request'], (error, @request) =>
        return done error if error?
        return done new Error('Got no request') unless @request?
        return done()

    it 'should create a GetAuthorizedSubscriptionTypes job', ->
      expect(@request.metadata.responseId).to.exist
      delete @request.metadata.responseId # We don't know what its gonna be

      expect(@request).to.containSubset
        metadata:
          auth: {uuid: 'u', token: 'p'}
          toUuid: 'u2'
          jobType: 'GetAuthorizedSubscriptionTypes'
        rawData: '["config","data","received"]'

  describe 'when a subscription is made and is allowed', ->
    beforeEach (done) ->
      @client.subscribe 'u2', (error, @granted) =>
        done error

      @jobManager.getRequest ['request'], (error, request) =>
        return done error if error?
        return done new Error('Got no request') unless request?
        response =
          metadata:
            code: 204
            status: 'No Content'
            responseId: request.metadata.responseId
          rawData: '{"types":["received"]}'
        @jobManager.createResponse 'response', response, (error) =>
          return done error if error?

    it 'should have granted the subscription', ->
      expect(@granted).to.deep.equal [{topic: 'u2', qos: 0}]

    describe 'when a message is sent', ->
      beforeEach (done) ->
        @client.on 'message', (fakeTopic, buffer) =>
          @mqttMessage = JSON.parse buffer.toString()
          done()

        @redisClient.publish 'received:u2', '{"devices":["*"],"payload":"hi"}', (error) =>
          return done error if error?

      it 'should forward the message to the client', ->
        expect(@mqttMessage.topic).to.deep.equal 'message'
