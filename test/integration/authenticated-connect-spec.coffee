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
    @jobManager = new JobManagerResponder {
      @namespace
      @redisUri
      maxConnections: 1
      jobTimeoutSeconds: 1
      queueTimeoutSeconds: 1
      jobLogSampleRate: 0
      @requestQueueName
      @responseQueueName
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

  describe 'when an mqtt client connects with a username/password', ->
    beforeEach ->
      {port} = @sut.address()
      @client  = mqtt.connect("mqtt://u:p@localhost:#{port}")

    afterEach (done) ->
      @client.end true, done

    it 'should create an Authenticate job to the dispatcher', (done) ->
      @jobManager.getRequest (error, request) =>
        expect(request.metadata.responseId).to.exist
        delete request.metadata.responseId # We don't know what its gonna be

        expect(request).to.containSubset
          metadata:
            auth: {uuid: 'u', token: 'p'}
            jobType: 'Authenticate'
          rawData: 'null'
        done()

    describe 'when the job responds with a status 204', ->
      beforeEach (done) ->
        @jobManager.do (request, callback) =>
          response =
            metadata:
              responseId: request.metadata.responseId
              code: 204
              status: 'No Content'
          callback null, response

        @client.on 'connect', => done()

      it 'should get here', ->
        expect(true).to.be.true

      describe 'when the client subscribes to itself', ->
        beforeEach (done) ->
          @client.subscribe 'u', (error, @granted) =>
            return done error

        it 'should get here', ->
          expect(@granted).to.deep.equal [{topic: 'u', qos: 0}]

    describe 'when the job responds with a status 401', ->
      beforeEach (done) ->
        @jobManager.do (request, callback) =>
          response =
            metadata:
              responseId: request.metadata.responseId
              code: 401
              status: 'Forbidden'
          callback null, response

        @client.on 'error', (@error) => done()

      it 'should emit an error', ->
        expect(=> throw @error).to.throw 'Connection refused: Bad username or password'
