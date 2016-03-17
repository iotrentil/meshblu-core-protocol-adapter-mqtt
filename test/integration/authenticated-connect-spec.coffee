_          = require 'lodash'
JobManager = require 'meshblu-core-job-manager'
mqtt       = require 'mqtt'
portfinder = require 'portfinder'
redis      = require 'redis'

RedisNS    = require '@octoblu/redis-ns'
Server     = require '../../src/server'

describe 'Connecting to the server with auth', ->
  beforeEach (done) ->
    portfinder.getPort (error, port) =>
      return done error if error?

      @sut = new Server
        port: port
        redisUri: 'redis://localhost:6379'
        namespace: 'ns'
        jobTimeoutSeconds: 1

      @sut.start done

  afterEach (done) ->
    @sut.stop done

  describe 'when an mqtt client connects with a username/password', ->
    beforeEach ->
      {port} = @sut.address()
      @client  = mqtt.connect("mqtt://u:p@localhost:#{port}")

    afterEach (done) ->
      @client.end done

    it 'should create an Authenticate job to the dispatcher', (done) ->
      jobManager = new JobManager
        client: _.bindAll new RedisNS 'ns', redis.createClient()
        timeoutSeconds: 1

      jobManager.getRequest ['request'], (error, request) =>
        return done error if error?
        expect(request.metadata.responseId).to.exist
        delete request.metadata.responseId # We don't know what its gonna be

        expect(request).to.deep.equal
          metadata:
            auth: {uuid: 'u', token: 'p'}
            jobType: 'Authenticate'
          rawData: 'null'
        done()
