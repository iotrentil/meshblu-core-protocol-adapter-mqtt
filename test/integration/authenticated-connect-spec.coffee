_          = require 'lodash'
JobManager = require 'meshblu-core-job-manager'
mqtt       = require 'mqtt'
portfinder = require 'portfinder'
redis      = require 'redis'

RedisNS    = require '@octoblu/redis-ns'
Server     = require '../../src/server'

describe 'Connecting to the server with auth', ->
  beforeEach (done) ->
    @jobManager = new JobManager
      client: _.bindAll new RedisNS 'ns', redis.createClient()
      timeoutSeconds: 1
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
      @client.end true, done

    it 'should create an Authenticate job to the dispatcher', (done) ->
      @jobManager.getRequest ['request'], (error, request) =>
        return done error if error?
        expect(request.metadata.responseId).to.exist
        delete request.metadata.responseId # We don't know what its gonna be

        expect(request).to.deep.equal
          metadata:
            auth: {uuid: 'u', token: 'p'}
            jobType: 'Authenticate'
          rawData: 'null'
        done()

    describe 'when the job responds with a status 204', ->
      beforeEach (done) ->
        @jobManager.getRequest ['request'], (error, request) =>
          return done error if error?
          return done new Error('no request received') unless request?

          response =
            metadata:
              responseId: request.metadata.responseId
              code: 204
              status: 'No Content'

          @jobManager.createResponse 'response', response, (error) =>
            return done error if error?

        @client.on 'connect', => done()

      it 'should get here', ->
        expect(true).to.be.true

    describe 'when the job responds with a status 403', ->
      beforeEach (done) ->
        @jobManager.getRequest ['request'], (error, request) =>
          response =
            metadata:
              responseId: request.metadata.responseId
              code: 403
              status: 'Forbidden'

          @jobManager.createResponse 'response', response, (error) =>
            return done error if error?

        @client.on 'error', (@error) => done()

      it 'should emit an error', ->
        expect(=> throw @error).to.throw 'Connection refused: Bad username or password'
