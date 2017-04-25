Connection = require '../connection'

describe 'Whoami', ->
  beforeEach (done) ->
    @workerFunc = sinon.stub()
    @connection = new Connection {@workerFunc}
    @connection.connect (error, {@client}={}) => done error

  afterEach (done) ->
    @connection.stopAll done

  describe 'when whoami is called and it responds with great success', ->
    beforeEach (done) ->
      @workerFunc.yields null, rawData: '{"iam":"here"}', metadata: code: 200
      @client.on 'message', (topic, @buffer) => done()
      message = JSON.stringify callbackId: 'callback-eye-D'
      @client.publish 'whoami', message, (error) =>
        return done error if error?

    it 'should create a whoami job', ->
      expect(@workerFunc).to.have.been.called
      expect(@workerFunc.firstCall.args[0]).to.containSubset
        metadata:
          jobType: 'GetDevice'
          auth: {uuid: 'u', token: 'p'}
          toUuid: 'u'
        rawData: 'null'

    it 'should send a success message to the client', ->
      message = JSON.parse @buffer.toString()
      expect(message).to.containSubset
        topic: 'whoami'
        data:
          iam: 'here'
        _request:
          callbackId: 'callback-eye-D'

  describe 'when whoami is called and it responds with great failure', ->
    beforeEach (done) ->
      @workerFunc.yields null, metadata: code: 403, status: 'Forbidden'
      @client.on 'error', (@error) => done()
      message = JSON.stringify callbackId: 'callback-eye-D'
      @client.publish 'whoami', message, (error) =>
        return done error if error?

    it 'should yield an error', ->
      expect(=> throw @error).to.throw 'Forbidden'

  describe 'when whoami is called and it responds with great failure', ->
    beforeEach (done) ->
      @client.on 'error', (@error) => done()
      message = JSON.stringify callbackId: 'callback-eye-D'
      @client.publish 'whoami', message, (error) =>
        return done error if error?

    it 'should yield an error', ->
      expect(=> throw @error).to.throw 'timeout'
