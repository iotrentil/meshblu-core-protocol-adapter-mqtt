Connection = require '../connection'

describe 'Reset Token', ->
  beforeEach (done) ->
    @connection = new Connection
    @connection.connect (error, {@server, @client, @jobManager}) =>
      return done error if error?
      done()

  afterEach (done) ->
    @connection.stopAll done

  describe 'when resetToken is called', ->
    beforeEach (done) ->
      message = JSON.stringify callbackId: 'callback-eye-D'
      @client.publish 'resetToken', message, done

    it 'should create a resetToken job', (done) ->
      @jobManager.getRequest (error, request) =>
        expect(request.metadata.responseId).to.exist
        delete request.metadata.responseId # We don't know what its gonna be

        expect(request).to.containSubset
          metadata:
            jobType: 'ResetToken'
            auth: {uuid: 'u', token: 'p'}
            toUuid: 'u'
          rawData: 'null'

        done()

    describe 'when the resetToken fails', ->
      beforeEach (done) ->
        @client.on 'error', (@error) => done()

        @jobManager.do (request, callback) =>
          response =
            metadata:
              responseId: request.metadata.responseId
              code: 403
              status: 'Forbidden'

          callback null, response

      it 'should send an error message to the client', ->
        expect(=> throw @error).to.throw 'resetToken failed: Forbidden'

    describe 'when the resetToken succeeds', ->
      beforeEach (done) ->
        @client.on 'message', (@fakeTopic, @buffer) => done()

        @jobManager.do (request, callback) =>
          response =
            metadata:
              responseId: request.metadata.responseId
              code: 200
              status: 'No Content'
            rawData: '{"uuid":"u","token":"t"}'

          callback null, response

      it 'should send a success message to the client', ->
        message = JSON.parse @buffer.toString()
        expect(message).to.containSubset
          topic: 'resetToken'
          data:
            uuid: 'u'
            token: 't'
          _request:
            callbackId: 'callback-eye-D'

    describe 'when the resetToken times out', ->
      beforeEach (done) ->
        @timeout 3000
        @client.on 'error', (@error) => done()
        @jobManager.do (request, callback) =>
          return done error if error?

      it 'should send an error message to the client', ->
        expect(=> throw @error).to.throw 'Response timeout exceeded'
