_          = require 'lodash'
async      = require 'async'
JobManager = require 'meshblu-core-job-manager'
mqtt       = require 'mqtt'
portfinder = require 'portfinder'
redis      = require 'redis'
RedisNS    = require '@octoblu/redis-ns'
Server     = require '../src/server'

class Connect
  constructor: ->

  connect: (callback) =>
    async.series {
      jobManager: @_createJobManager
      server: @_createServer
      client: @_createClient
    }, callback

  stopAll: (callback) =>
    async.series [@_stopClient, @_stopServer, @_stopJobManager], callback

  _createClient: (callback) =>
    callback = _.once callback

    {port} = @server.address()
    @client = mqtt.connect("mqtt://u:p@localhost:#{port}")
    @client.on 'connect', => callback null, @client
    @client.on 'error', callback
    @_respondToLoginAttempt (error) =>
      return callback error if error?

  _createJobManager: (callback) =>
    client = _.bindAll new RedisNS 'ns', redis.createClient()
    @jobManager = new JobManager client: client, timeoutSeconds: 1
    return callback null, @jobManager

  _createServer: (callback) =>
    portfinder.getPort (error, port) =>
      return callback error if error?
      @server = new Server
        port: port
        redisUri: 'redis://localhost:6379'
        namespace: 'ns'
        jobLogQueue: 'foo'
        jobLogRedisUri: 'redis://localhost:6379'
        jobLogSampleRate: 0
        jobTimeoutSeconds: 1
        connectionPoolMaxConnections: 1

      @server.start (error) =>
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

  _stopServer: (callback) =>
    @server.stop callback

module.exports = Connect
