_          = require 'lodash'
async      = require 'async'
JobManager = require 'meshblu-core-job-manager'
mqtt       = require 'mqtt'
portfinder = require 'portfinder'
redis      = require 'ioredis'
RedisNS    = require '@octoblu/redis-ns'
Server     = require '../src/server'

class Connection
  constructor: ->

  connect: (callback) =>
    async.series {
      redisClient: @_createRedisClient
      jobManager: @_createJobManager
      server: @_createServer
      client: @_createClient
    }, callback

  stopAll: (callback) =>
    async.series [@_stopClient, @_stopServer, @_stopJobManager, @_stopRedisClient], callback

  _createClient: (callback) =>
    callback = _.once callback

    {port} = @server.address()
    @client = mqtt.connect("mqtt://u:p@localhost:#{port}")
    @client.on 'connect', =>
      @client.subscribe 'u', (error, granted) =>
        throw error if error?
        throw new Error('Failed to subscribe') unless _.isEqual granted, [{topic: 'u', qos: 0}]
        callback null, @client

    @client.on 'message', (fakeTopic, buffer) =>
      message = JSON.parse buffer.toString()
      @client.emit 'error', new Error(message.data.message) if message.topic == 'error'

    @_respondToLoginAttempt (error) =>
      return callback error if error?

  _createJobManager: (callback) =>
    client = new RedisNS 'ns', redis.createClient(dropBufferSupport: true)
    @jobManager = new JobManager client: client, timeoutSeconds: 1
    return callback null, @jobManager

  _createRedisClient: (callback) =>
    @redisClient = new RedisNS 'ns', redis.createClient(dropBufferSupport: true)
    return callback null, @redisClient

  _createServer: (callback) =>
    portfinder.getPort (error, port) =>
      return callback error if error?
      @server = new Server
        port: port
        redisUri: 'redis://localhost:6379'
        firehouseRedisUri: 'redis://localhost:6379'
        namespace: 'ns'
        jobLogQueue: 'foo'
        jobLogRedisUri: 'redis://localhost:6379'
        jobLogSampleRate: 0
        jobTimeoutSeconds: 1
        maxConnections: 1

      @server.run (error) =>
        return callback error if error?
        return callback null, @server

  _respondToLoginAttempt: (callback) =>
    @jobManager.getRequest ['request'], (error, request) =>
      return callback error if error?
      return callback new Error('no request received') unless request?

      response =
        metadata:
          responseId: request.metadata.responseId
          code: 204
          status: 'No Content'

      @jobManager.createResponse 'response', response, callback

  _stopClient: (callback) =>
    @client.end true, callback

  _stopJobManager: (callback) =>
    @jobManager # uhm... *cough* ...nothing to see here
    callback()

  _stopRedisClient: (callback) =>
    @redisClient.end false # flush false, silently fails currently running commands
    callback()

  _stopServer: (callback) =>
    @server.stop callback

module.exports = Connection
