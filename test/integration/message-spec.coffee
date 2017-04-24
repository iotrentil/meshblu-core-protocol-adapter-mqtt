_ = require 'lodash'
Connection = require '../connection'

describe 'Message', ->
  beforeEach (done) ->
    @workerFunc = sinon.stub().yields null, metadata: code: 204
    @connection = new Connection {@workerFunc}
    @connection.connect (error, {@client}) =>
      return done error if error?
      done()

  afterEach (done) ->
    @connection.stopAll done

  describe 'when message is called', ->
    beforeEach (done) ->
      message = JSON.stringify devices: ['*'], payload: 'hi'
      @client.publish 'message', message, => _.delay done, 200

    it 'should create a message job', ->
      expect(@workerFunc).to.have.been.called
      expect(@workerFunc.firstCall.args[0]).to.containSubset
          metadata:
            jobType: 'SendMessage'
            auth: {uuid: 'u', token: 'p'}
          rawData: '{"devices":["*"],"payload":"hi"}'
