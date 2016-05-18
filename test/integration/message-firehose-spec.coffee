Connection = require '../connection'

describe.only 'Receiving a message', ->
  beforeEach (done) ->
    @jobby = =>
      @jobManager.getRequest ['request'], (error, request) =>
        console.log JSON.stringify {wut:{error,request}}, null, 2
        return @jobby unless request?

        response =
          metadata:
            responseId: request.metadata.responseId
            code: 204
            status: 'No Content'

        @jobManager.createResponse 'response', response, @jobby

    @connection = new Connection
    @connection.connect (error, {@client, @jobManager}) =>
      return done error if error?

      # @jobManager.getRequest ['request'], (error, request) =>
      #   console.log auth: {request}
      #   return done error if error?
      #   # return callback new Error('no request received') unless request?
      #
      #   response =
      #     metadata:
      #       responseId: request.metadata.responseId
      #       code: 204
      #       status: 'No Content'
      #
      #   @jobManager.createResponse 'response', response, =>
      #     console.log 'wow'
      # @jobby()
      done()

  afterEach (done) ->
    @connection.stopAll done

  describe 'when a message is sent', ->
    beforeEach (done) ->
      console.log 'connecting the firehose...'
      message = JSON.stringify connect: true
      # @connection._respondToLoginAttempt =>
      @client.publish 'meshblu/firehose', message, =>
        @connection._respondToLoginAttempt =>
          @jobby()
          done()

    beforeEach (done) ->
      console.log 'sending a message...'
      message = JSON.stringify
        job:
          rawData: '{"devices":["u"],"payload":"wow"}'
          metadata:
            jobType: 'SendMessage'
            toUuid: 'u'
      @client.publish 'meshblu/request', message, done

    beforeEach (done) ->
      console.log 'waiting for a response...'
      @client.on 'message/parsed', (@mqttMessage) =>
        console.log 'got a response!'
        done()

    it 'should forward the message to the client', ->
      expect(@mqttMessage).to.deep.equal {}
