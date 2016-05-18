debug      = require('debug')('meshblu-core-protocol-adapter-mqtt:anonymous-connect-spec')
_          = require 'lodash'
JobManager = require 'meshblu-core-job-manager'
redis      = require 'ioredis'
mqtt       = require 'mqtt'
portfinder = require 'portfinder'
RedisNS    = require '@octoblu/redis-ns'
Server     = require '../../src/server'

describe 'Connecting to the server anonymously', ->
  beforeEach (done) ->
    @jobManager = new JobManager
      client: new RedisNS 'ns', redis.createClient()
      timeoutSeconds: 1

    portfinder.getPort (error, @port) =>
      return done error if error?
      @sut = new Server
        redisUri: 'redis://localhost:6379'
        namespace: 'ns'
        jobLogQueue: 'foo'
        jobLogRedisUri: 'redis://localhost:6379'
        jobLogSampleRate: 0
        jobTimeoutSeconds: 1
        connectionPoolMaxConnections: 1
        moscaOptions:
          port: @port

      @sut.start done

  afterEach (done) ->
    @sut.stop done

  describe 'when a generic, anonymous mqtt client connects', ->
    beforeEach ->
      debug "connecting to #{@port}"
      @client  = mqtt.connect("mqtt://localhost:#{@port}")

    afterEach (done) ->
      @client.end true, done

    beforeEach (done) ->
      @client.on 'connect', (@msg) => done()

    it 'should not reject the connection', ->
      expect(@msg.cmd).to.equals 'connack'
