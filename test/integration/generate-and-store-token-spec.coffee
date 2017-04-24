Connection = require '../connection'
_ = require 'lodash'
describe 'Generate and Store Token', ->
  beforeEach (done) ->
    @workerFunc = sinon.stub()

    @connection = new Connection {@workerFunc}
    @connection.connect (error, {@client}) =>
      return done error if error?
      done()

  afterEach (done) ->
    @connection.stopAll done

  describe 'when generateAndStoreToken succeeds', ->
    beforeEach (done) ->
      response =
        metadata:
          code: 200
        rawData: JSON.stringify uuid: 'u', token: 't'
      @workerFunc.yields null, response
      message = JSON.stringify callbackId: 'callback-eye-D'
      @client.on 'message', (topic, @buffer) => done()
      @client.publish 'generateAndStoreToken', message, (error) =>
        return done error if error?

    it 'should create a generateAndStoreToken job', ->
      expect(@workerFunc).to.have.been.called
      request = @workerFunc.firstCall.args[0]
      expect(request).to.have.deep.property 'metadata.responseId'
      expect(request).to.containSubset
        metadata:
          jobType: 'CreateSessionToken'
          auth: {uuid: 'u', token: 'p'}
          toUuid: 'u'
        rawData: 'null'

    it 'should respond with the generated token', ->
      message = JSON.parse @buffer.toString()
      expect(message).to.containSubset
        topic: 'generateAndStoreToken'
        data:
          uuid: 'u'
          token: 't'

  describe 'when generateAndStoreToken fails', ->
    beforeEach (done) ->
      response =
        metadata:
          code: 403
          status: 'Forbidden'
      @workerFunc.yields null, response
      message = JSON.stringify callbackId: 'callback-eye-D'
      @client.publish 'generateAndStoreToken', message, (error) => return done error if error?

      @client.on 'error', (@error) => done()

    it 'should send an error message to the client', ->
      expect(=> throw @error).to.throw 'generateAndStoreToken failed: Forbidden'

  describe 'when the generateAndStoreToken times out', ->
    beforeEach (done) ->
      @timeout 3000
      @client.on 'error', (@error) => done()
      message = JSON.stringify callbackId: 'callback-eye-D'
      @client.publish 'generateAndStoreToken', message, (error) =>
        done error if error?

    it 'should send an error message to the client', ->
      expect(=> throw @error).to.throw 'Response timeout exceeded'
