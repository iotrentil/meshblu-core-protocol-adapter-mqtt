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
      message = JSON.stringify uuid: 'u2', foo: 'bar'
      @client.publish 'update', message, done

    it 'should create an update job', (done) ->
      @jobManager.getRequest ['request'], (error, request) =>
        return done error if error?

        expect(request.metadata.responseId).to.exist
        delete request.metadata.responseId # We don't know what its gonna be

        expect(request).to.deep.equal
          metadata:
            jobType: 'UpdateDevice'
            auth: {uuid: 'u', token: 'p'}
            toUuid: 'u2'
          rawData: '{"foo":"bar"}'

        done()
