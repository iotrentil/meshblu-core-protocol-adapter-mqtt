Connection = require '../connection'

describe 'Message', ->
  beforeEach (done) ->
    @connection = new Connection
    @connection.connect (error, {@server, @client, @jobManager}) =>
      return done error if error?
      done()

  afterEach (done) ->
    @connection.stopAll done

  describe 'when message is called', ->
    beforeEach (done) ->
      message = JSON.stringify devices: ['*'], payload: 'hi'
      @client.publish 'message', message, done

    it 'should create a message job', (done) ->
      @jobManager.getRequest (error, request) =>
        return done error if error?

        expect(request.metadata.responseId).to.exist
        delete request.metadata.responseId # We don't know what its gonna be

        expect(request).to.containSubset
          metadata:
            jobType: 'SendMessage'
            auth: {uuid: 'u', token: 'p'}
          rawData: '{"devices":["*"],"payload":"hi"}'

        done()
