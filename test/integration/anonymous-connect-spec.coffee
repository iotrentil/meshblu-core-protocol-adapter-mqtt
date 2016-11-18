_          = require 'lodash'
Redis      = require 'ioredis'
mqtt       = require 'mqtt'
portfinder = require 'portfinder'
RedisNS    = require '@octoblu/redis-ns'
Server     = require '../../src/server'
UUID       = require 'uuid'
{ JobManagerResponder } = require 'meshblu-core-job-manager'

describe 'Connecting to the server anonymously', ->
  beforeEach (done) ->
    queueId = UUID.v4()
    @requestQueueName = "test:request:queue:#{queueId}"
    @responseQueueName = "test:response:queue:#{queueId}"
    @jobManager = new JobManagerResponder {
      client: new RedisNS 'ns', new Redis 'localhost', dropBufferSupport: true
      queueClient: new RedisNS 'ns', new Redis 'localhost', dropBufferSupport: true
      jobTimeoutSeconds: 1
      queueTimeoutSeconds: 1
      jobLogSampleRate: 0
      @requestQueueName
      @responseQueueName
    }

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

  describe 'when a generic, anonymous mqtt client connects', ->
    beforeEach ->
      {port} = @sut.address()
      @client  = mqtt.connect("mqtt://localhost:#{port}")

    afterEach (done) ->
      @client.end true, done

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

      it 'should reject the connection an error', ->
        expect(=> throw @error).to.throw 'Connection refused: Bad username or password'
