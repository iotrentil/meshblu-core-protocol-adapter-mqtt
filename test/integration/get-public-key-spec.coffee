Connection = require '../connection'

describe 'Get Public Key', ->
  beforeEach (done) ->
    @connection = new Connection
    @connection.connect (error, {@server, @client, @jobManager}) =>
      return done error if error?
      done()

  afterEach (done) ->
    @connection.stopAll done

  describe 'when getPublicKey is called', ->
    beforeEach (done) ->
      message = JSON.stringify
        callbackId: 'callback-eye-D'
        job:
          rawData: 'null'
          metadata:
            jobType: 'GetDevicePublicKey'
            toUuid: 'u'
      @client.publish 'meshblu/request', message, done

    it 'should create a getPublicKey job', (done) ->
      @jobManager.getRequest ['request'], (error, request) =>
        return done error if error?

        expect(request.metadata.responseId).to.exist
        delete request.metadata.responseId # We don't know what its gonna be

        expect(request).to.containSubset
          metadata:
            jobType: 'GetDevicePublicKey'
            auth: {uuid: 'u', token: 'p'}
            toUuid: 'u'
          rawData: 'null'

        done()

    describe 'when the getPublicKey fails', ->
      beforeEach (done) ->
        @client.on 'message', (@fakeTopic, buffer) =>
          try
            @result = JSON.parse buffer.toString()
          catch error
            done(error)
          done()

        @jobManager.getRequest ['request'], (error, request) =>
          return done error if error?
          return done new Error('no request received') unless request?

          response =
            metadata:
              responseId: request.metadata.responseId
              code: 403
              status: 'Forbidden'

          @jobManager.createResponse 'response', response, (error) =>
            return done error if error?

      it 'should send an error message to the client', ->
        expect(@result.data).to.equals 'Forbidden'

    describe 'when the getPublicKey succeeds', ->
      beforeEach (done) ->
        @client.on 'message', (@fakeTopic, @buffer) => done()

        @jobManager.getRequest ['request'], (error, request) =>
          return done error if error?
          return done new Error('no request received') unless request?

          response =
            metadata:
              responseId: request.metadata.responseId
              code: 200
              status: 'No Content'
            rawData: '{"uuid":"u","token":"t"}'

          @jobManager.createResponse 'response', response, (error) =>
            return done error if error?

      it 'should send a success message to the client', ->
        message = JSON.parse @buffer.toString()
        expect(message).to.containSubset
          topic: 'getPublicKey'
          data:
            uuid: 'u'
            token: 't'
          _request:
            callbackId: 'callback-eye-D'

    describe 'when the getPublicKey times out', ->
      beforeEach (done) ->
        @timeout 3000
        @client.on 'error', (@error) => done()
        @jobManager.getRequest ['request'], (error, request) =>
          return done error if error?

      it 'should send an error message to the client', ->
        expect(=> throw @error).to.throw 'Response timeout exceeded'
