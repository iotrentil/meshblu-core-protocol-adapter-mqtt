_          = require 'lodash'
JobManager = require 'meshblu-core-job-manager'
redis      = require 'redis'
mqtt       = require 'mqtt'
portfinder = require 'portfinder'
RedisNS    = require '@octoblu/redis-ns'
Server     = require '../../src/server'

describe 'Connecting to the server anonymously', ->
  beforeEach (done) ->
    @jobManager = new JobManager
      client: new RedisNS 'ns', redis.createClient()
      timeoutSeconds: 1

    portfinder.getPort (error, port) =>
      return done error if error?
      @sut = new Server
        port: port
        redisUri: 'redis://localhost:6379'
        namespace: 'ns'
        jobLogQueue: 'foo'
        jobLogRedisUri: 'redis://localhost:6379'
        jobLogSampleRate: 0
        jobTimeoutSeconds: 1
        connectionPoolMaxConnections: 1

      @sut.start done

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
        @jobManager.getRequest ['request'], (error, request) =>
          return done error if error?
          return done new Error('no request received') unless request?

          response =
            metadata:
              responseId: request.metadata.responseId
              code: 401
              status: 'Forbidden'

          @jobManager.createResponse 'response', response, (error) =>
            return done error if error?

        @client.on 'error', (@error) => done()

      it 'should reject the connection an error', ->
        expect(=> throw @error).to.throw 'Connection refused: Bad username or password'
