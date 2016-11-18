Connection = require '../connection'

describe 'Whoami', ->
  beforeEach (done) ->
    @connection = new Connection
    @connection.connect (error, {@server, @client, @jobManager}) =>
      return done error if error?
      done()

  afterEach (done) ->
    @connection.stopAll done

  describe 'when whoami is called', ->
    beforeEach (done) ->
      message = JSON.stringify callbackId: 'callback-eye-D'
      @client.publish 'whoami', message, done

    it 'should create a whoami job', (done) ->
      @jobManager.getRequest (error, request) =>
        return done error if error?

        expect(request.metadata.responseId).to.exist
        delete request.metadata.responseId # We don't know what its gonna be

        expect(request).to.containSubset
          metadata:
            jobType: 'GetDevice'
            auth: {uuid: 'u', token: 'p'}
            toUuid: 'u'
          rawData: 'null'

        done()

    describe 'when the whoami fails', ->
      beforeEach (done) ->
        @client.on 'error', (@error) => done()

        @jobManager.do (request, callback) =>
          return done error if error?
          return done new Error('no request received') unless request?

          response =
            metadata:
              responseId: request.metadata.responseId
              code: 403
              status: 'Forbidden'

          callback null, response

      it 'should send an error message to the client', ->
        expect(=> throw @error).to.throw 'whoami failed: Forbidden'

    describe 'when the whoami succeeds', ->
      beforeEach (done) ->
        @client.on 'message', (@fakeTopic, @buffer) => done()

        @jobManager.do (request, callback) =>
          return done error if error?
          return done new Error('no request received') unless request?

          response =
            metadata:
              responseId: request.metadata.responseId
              code: 200
              status: 'OK'
            rawData: '{"name":"foo"}'

          callback null, response

      it 'should send a success message to the client', ->
        message = JSON.parse @buffer.toString()
        expect(message).to.containSubset
          topic: 'whoami'
          data:
            name: 'foo'
          _request:
            callbackId: 'callback-eye-D'

    describe 'when the whoami times out', ->
      beforeEach (done) ->
        @timeout 3000
        @client.on 'error', (@error) => done()
        @jobManager.do (request, callback) =>
          return done error if error?

      it 'should send an error message to the client', ->
        expect(=> throw @error).to.throw 'Response timeout exceeded'
