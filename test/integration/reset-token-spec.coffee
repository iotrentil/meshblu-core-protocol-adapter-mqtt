Connection = require '../connection'

describe 'Reset Token', ->
  beforeEach (done) ->
    @workerFunc = sinon.stub()
    @connection = new Connection {@workerFunc}
    @connection.connect (error, {@client}={}) => done error

  afterEach (done) ->
    @connection.stopAll done

  describe 'when resetToken responds well', ->
    beforeEach (done) ->
      @workerFunc.yields null, rawData: '{"uuid":"u","token":"t"}', metadata: code: 200
      message = JSON.stringify callbackId: 'callback-eye-D'

      @client.publish 'resetToken', message
      @client.on 'message', (@topic, @buffer) => done()

    it 'should create a resetToken job', ->
      expect(@workerFunc).to.have.been.called
      expect(@workerFunc.firstCall.args[0]).to.containSubset
        metadata:
          jobType: 'ResetToken'
          auth: {uuid: 'u', token: 'p'}
          toUuid: 'u'
        rawData: 'null'

    it 'should respond with the data', ->
      expect(JSON.parse @buffer.toString()).to.containSubset
        topic: 'resetToken'
        data:
          uuid: 'u'
          token: 't'
        _request:
          callbackId: 'callback-eye-D'

  describe 'when the resetToken responds poorly', ->
    beforeEach (done) ->
      @workerFunc.yields null, metadata: {code: 403, status: 'Forbidden'}
      message = JSON.stringify callbackId: 'callback-eye-D'
      @client.publish 'resetToken', message, (error) => done error if error?
      @client.on 'error', (@error) => done()

    it 'should send an error message to the client', ->
      expect(=> throw @error).to.throw 'resetToken failed: Forbidden'


  describe 'when the resetToken times out', ->
    beforeEach (done) ->
      @timeout 3000
      message = JSON.stringify callbackId: 'callback-eye-D'
      @client.publish 'resetToken', message, (error) => done error if error?
      @client.on 'error', (@error) => done()

    it 'should send an error message to the client', ->
      expect(=> throw @error).to.throw 'Response timeout exceeded'
