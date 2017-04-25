Connection = require '../connection'

describe 'Update', ->
  beforeEach (done) ->
    @workerFunc = sinon.stub()
    @connection = new Connection {@workerFunc}
    @connection.connect (error, {@client}={}) => done error

  afterEach (done) ->
    @connection.stopAll done

  describe 'when update goes well', ->
    beforeEach (done) ->
      @workerFunc.yields null, metadata: code: 204
      message = JSON.stringify
        uuid: 'u2'
        foo: 'bar'
        callbackId: 'callback-eye-D'

      @client.on 'message', (@topic, @buffer) => done()
      @client.publish 'update', message

    it 'should create an update job', ->
      expect(@workerFunc).to.have.been.called
      expect(@workerFunc.firstCall.args[0]).to.containSubset
          metadata:
            jobType: 'UpdateDevice'
            auth: {uuid: 'u', token: 'p'}
            toUuid: 'u2'
          rawData: '{"$set":{"foo":"bar"}}'

    it 'should send a success message to the client', ->
      message = JSON.parse @buffer.toString()
      expect(message).to.containSubset
        topic: 'update'
        data: {}
        _request:
          callbackId: 'callback-eye-D'

  describe 'when the update fails', ->
    beforeEach (done) ->
      @workerFunc.yields null, metadata: {code: 403, status: 'Forbidden'}
      @client.on 'error', (@error) => done()

      message = JSON.stringify
        uuid: 'u2'
        foo: 'bar'
        callbackId: 'callback-eye-D'

      @client.publish 'update', message

    it 'should send an error message to the client', ->
      expect(=> throw @error).to.throw 'update failed: Forbidden'

  describe 'when the update times out', ->
    beforeEach (done) ->
      @timeout 3000
      @client.on 'error', (@error) => done()
      message = JSON.stringify
        uuid: 'u2'
        foo: 'bar'
        callbackId: 'callback-eye-D'

      @client.publish 'update', message

    it 'should send an error message to the client', ->
      expect(=> throw @error).to.throw 'Response timeout exceeded'
