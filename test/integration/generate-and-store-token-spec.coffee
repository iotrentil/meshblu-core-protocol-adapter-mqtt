Connection = require '../connection'

describe 'Generate and Store Token', ->
  beforeEach (done) ->
    @connection = new Connection
    @connection.connect (error, {@server, @client, @jobManager}) =>
      return done error if error?
      done()

  afterEach (done) ->
    @connection.stopAll done

  describe 'when generateAndStoreToken is called', ->
    beforeEach (done) ->
      message = JSON.stringify
        callbackId: 'callback-eye-D'
        job:
          rawData: 'null'
          metadata:
            jobType: 'CreateSessionToken'
            toUuid: 'u'

      @client.publish 'meshblu/request', message, done

    it 'should create a generateAndStoreToken job', (done) ->
      @jobManager.getRequest ['request'], (error, request) =>
        return done error if error?

        expect(request.metadata.responseId).to.exist
        delete request.metadata.responseId # We don't know what its gonna be

        expect(request).to.containSubset
          metadata:
            jobType: 'CreateSessionToken'
            auth: {uuid: 'u', token: 'p'}
            toUuid: 'u'
          rawData: 'null'

        done()

    describe 'when the generateAndStoreToken fails', ->
      beforeEach (done) ->
        @client.on 'message/parsed', (@result) => done()

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
        expect(@result).to.deep.equal {
          type: 'meshblu/error',
          data: 'Forbidden',
          callbackId: 'callback-eye-D'
        }

    describe 'when the generateAndStoreToken succeeds', ->
      beforeEach (done) ->
        @client.on 'message/parsed', (@result) => done()

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
        expect(@result).to.containSubset
          type: 'meshblu/response'
          data: JSON.stringify {uuid: 'u', token: 't'}
          callbackId: 'callback-eye-D'

    describe 'when the generateAndStoreToken times out', ->
      beforeEach (done) ->
        @client.on 'message/parsed', (@result) => done()

      # beforeEach (done) ->
        @timeout 3000
        @client.on 'error', (@error) => done()
        @jobManager.getRequest ['request'], (error, request) =>
          return done error if error?

      it 'should send an error message to the client', ->
        expect(@result.data).to.equal 'null response from job manager'
