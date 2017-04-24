Connection = require '../connection'

describe 'Subscribing to messages', ->
  beforeEach (done) ->
    @workerFunc = sinon.stub()
    @connection = new Connection {@workerFunc}
    @connection.connect (error, {@client, @redisClient}={}) =>
      return done error if error?
      done()

  afterEach (done) ->
    @connection.stopAll done

  describe 'when making a subscription responds well', ->
    beforeEach (done) ->
      @workerFunc.yields null, {
        metadata: {code: 204}
        rawData: '{"types": ["received"]}'
      }

      @client.subscribe 'u2', (error, @granted) => done error

    it 'should create a GetAuthorizedSubscriptionTypes job', ->
      expect(@workerFunc).to.have.been.called
      expect(@workerFunc.firstCall.args[0]).to.containSubset
        metadata:
          auth: {uuid: 'u', token: 'p'}
          toUuid: 'u2'
          jobType: 'GetAuthorizedSubscriptionTypes'
        rawData: '["config","data","received"]'

    it 'should grant the subscription', ->
      expect(@granted).to.deep.equal [{topic: 'u2', qos: 0}]

    describe 'when a message is sent', ->
      beforeEach (done) ->
        @client.on 'message', (fakeTopic, buffer) =>
          @mqttMessage = JSON.parse buffer.toString()
          done()

        @redisClient.publish 'received:u2', '{"devices":["*"],"payload":"hi"}', (error) =>
          return done error if error?
        return # stupid promises

      it 'should forward the message to the client', ->
        expect(@mqttMessage.topic).to.deep.equal 'message'

  describe 'when a subscription is made and is not good k?', ->
    beforeEach (done) ->
      @workerFunc.yields null, {
        metadata: {code: 403}
      }

      @client.subscribe 'u2', (error, @granted) => done error

    it 'should not have granted the subscription', ->
      expect(@granted).to.deep.equal [{topic: 'u2', qos: 128}]
