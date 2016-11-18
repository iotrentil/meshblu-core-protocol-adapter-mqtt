Connection = require '../connection'

describe 'Update', ->
  beforeEach (done) ->
    @connection = new Connection
    @connection.connect (error, {@server, @client, @jobManager}) =>
      return done error if error?
      done()

  afterEach (done) ->
    @connection.stopAll done

  describe 'when update is called', ->
    beforeEach (done) ->
      message = JSON.stringify
        uuid: 'u2'
        foo: 'bar'
        callbackId: 'callback-eye-D'
      @client.publish 'update', message, done

    it 'should create an update job', (done) ->
      @jobManager.getRequest (error, request) =>
        return done error if error?

        expect(request.metadata.responseId).to.exist
        delete request.metadata.responseId # We don't know what its gonna be

        expect(request).to.containSubset
          metadata:
            jobType: 'UpdateDevice'
            auth: {uuid: 'u', token: 'p'}
            toUuid: 'u2'
          rawData: '{"$set":{"foo":"bar"}}'

        done()

    describe 'when the update fails', ->
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
        expect(=> throw @error).to.throw 'update failed: Forbidden'

    describe 'when the update succeeds', ->
      beforeEach (done) ->
        @client.on 'message', (@fakeTopic, @buffer) => done()

        @jobManager.do (request, callback) =>
          return done error if error?
          return done new Error('no request received') unless request?

          response =
            metadata:
              responseId: request.metadata.responseId
              code: 204
              status: 'No Content'

          callback null, response

      it 'should send a success message to the client', ->
        message = JSON.parse @buffer.toString()
        expect(message).to.containSubset
          topic: 'update'
          data: {}
          _request:
            callbackId: 'callback-eye-D'

    describe 'when the update times out', ->
      beforeEach (done) ->
        @timeout 3000
        @client.on 'error', (@error) => done()
        @jobManager.do (request, callback) =>
          return done error if error?

      it 'should send an error message to the client', ->
        expect(=> throw @error).to.throw 'Response timeout exceeded'
