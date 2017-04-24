Connection = require '../connection'

describe 'Get Public Key', ->
  beforeEach (done) ->
    @workerFunc = sinon.stub()
    @connection = new Connection {@workerFunc}
    @connection.connect (error, {@client}={}) => done error

  afterEach (done) ->
    @connection.stopAll done

  describe 'when getPublicKey responds well', ->
    beforeEach (done) ->
      @workerFunc.yields null, rawData: '{"publicKey": "pubnub"}', metadata: code: 200
      message = JSON.stringify callbackId: 'callback-eye-D'
      @client.on 'message', (@topic, @buffer) => done()
      @client.publish 'getPublicKey', message, (error) => done error if error?

    it 'should create a getPublicKey job', ->
      expect(@workerFunc).to.have.been.called
      expect(@workerFunc.firstCall.args[0]).to.containSubset
        metadata:
          jobType: 'GetDevicePublicKey'
          auth: {uuid: 'u', token: 'p'}
          toUuid: 'u'
        rawData: 'null'

    it 'should respond with the data', ->
      expect(JSON.parse @buffer.toString()).to.containSubset data: publicKey: "pubnub"

  describe 'when the getPublicKey responds poorly', ->
    beforeEach (done) ->
      @workerFunc.yields null, metadata: {code: 403, status: 'Forbidden'}
      message = JSON.stringify callbackId: 'callback-eye-D'
      @client.publish 'getPublicKey', message, (error) => done error if error?
      @client.on 'error', (@error) => done()

    it 'should send an error message to the client', ->
      expect(=> throw @error).to.throw 'getPublicKey failed: Forbidden'

  describe 'when the getPublicKey responds never?', ->
    beforeEach (done) ->
      @timeout 3000
      message = JSON.stringify callbackId: 'callback-eye-D'
      @client.publish 'getPublicKey', message, (error) => done error if error?
      @client.on 'error', (@error) => done()

    it 'should send an error message to the client', ->
      expect(=> throw @error).to.throw 'Response timeout exceeded'
