_          = require 'lodash'
Redis      = require 'ioredis'
mqtt       = require 'mqtt'
portfinder = require 'portfinder'
RedisNS    = require '@octoblu/redis-ns'
Server     = require '../../src/server'
UUID       = require 'uuid'
{ JobManagerResponder } = require 'meshblu-core-job-manager'

describe 'Connecting to the server anonymously', ->
  beforeEach ->
    queueId = UUID.v4()
    @requestQueueName = "test:request:queue:#{queueId}"
    @responseQueueName = "test:response:queue:#{queueId}"
    @namespace = 'ns'
    @redisUri = 'redis://localhost'

  beforeEach (done) ->
    @workerFunc = sinon.stub()
    @jobManager = new JobManagerResponder {
      @namespace
      @redisUri
      maxConnections: 1
      jobTimeoutSeconds: 1
      queueTimeoutSeconds: 1
      jobLogSampleRate: 0
      @requestQueueName
      @responseQueueName
      @workerFunc
    }
    @jobManager.start done

  afterEach (done) ->
    @jobManager.stop done

  beforeEach (done) ->
    portfinder.getPort (error, port) =>
      return done error if error?
      @sut = new Server {
        port: port
        redisUri: 'redis://localhost:6379'
        cacheRedisUri: 'redis://localhost:6379'
        firehoseRedisUri: 'redis://localhost:6379'
        namespace: 'ns'
        jobLogQueue: 'foo'
        jobLogRedisUri: 'redis://localhost:6379'
        jobLogSampleRate: 0
        jobTimeoutSeconds: 1
        maxConnections: 1
        @requestQueueName
        @responseQueueName
      }

      @sut.run done

  afterEach (done) ->
    @sut.stop done

  describe 'when an mqtt client connects with a good username/password', ->
    beforeEach (done) ->
      response =
        metadata:
          code: 204
      @workerFunc.yields null, response

      {port} = @sut.address()
      @client  = mqtt.connect "mqtt://u:p@localhost:#{port}"
      @client.on 'connect', => done()

    afterEach (done) ->
      @client.end true, done

    it 'should create an Authenticate job to the dispatcher', ->
      request =
        metadata:
          auth: {uuid: 'u', token: 'p'}
          jobType: 'Authenticate'
        rawData: 'null'

      expect(@workerFunc.firstCall.args[0]).to.containSubset request

    describe 'when the client subscribes to itself', ->
      beforeEach (done) ->
        @client.subscribe 'u', (error, @granted) =>
          return done error

      it 'should get here', ->
        expect(@granted).to.deep.equal [{topic: 'u', qos: 0}]


  describe 'when an mqtt client connects with a bad username/password', ->
    beforeEach (done) ->
      response =
        metadata:
          code: 401
      @workerFunc.yields null, response

      {port} = @sut.address()
      @client = mqtt.connect "mqtt://u:p@localhost:#{port}"
      @client.on 'error', (@error) => done()

    afterEach (done) ->
      @client.end true, done

    it 'should emit an error', ->
      expect(=> throw @error).to.throw 'Connection refused: Bad username or password'
