_                = require 'lodash'
PooledJobManager = require 'meshblu-core-pooled-job-manager'
RedisNS          = require '@octoblu/redis-ns'
redis            = require 'redis'
mosca            = require 'mosca'
JobLogger        = require 'job-logger'
{Pool}           = require 'generic-pool'

class Server
  constructor: (options) ->
    {@port, @redisUri, @namespace, @jobTimeoutSeconds} = options
    {@jobLogRedisUri, @jobLogQueue, @jobLogSampleRate} = options

    connectionPool = @_createConnectionPool()
    jobLogger = new JobLogger
      indexPrefix: 'metric:meshblu-server-mqtt'
      type: 'meshblu-server-mqtt:request'
      client: redis.createClient(@jobLogRedisUri)
      jobLogQueue: @jobLogQueue
      sampleRate: @jobLogSampleRate

    @jobManager = new PooledJobManager
      timeoutSeconds: @jobTimeoutSeconds
      pool: connectionPool
      jobLogger: jobLogger

  address: =>
    {address: '0.0.0.0', port: @port}

  authenticate: (client, username, password, callback) =>
    job =
      metadata:
        auth: {uuid: username, token: password?.toString()}
        jobType: 'Authenticate'

    @jobManager.do 'request', 'response', job, (error, response) =>
      return callback error if error?
      return callback new Error('unauthorized') unless response.metadata.code == 204
      callback null, true

  start: (callback) =>
    @server = mosca.Server {@port}

    @server.on 'ready', => @onReady callback
    @server.on 'clientConnected', @onConnect

  stop: (callback) =>
    @server.close callback

  onConnect: (client) =>

  onReady: (callback) =>
    @server.authenticate = @authenticate
    callback()

  _createConnectionPool: =>
    connectionPool = new Pool
      max: @connectionPoolMaxConnections
      min: 0
      returnToHead: true # sets connection pool to stack instead of queue behavior
      create: (callback) =>
        client = new RedisNS @namespace, redis.createClient(@redisUri)

        client.on 'end', ->
          client.hasError = new Error 'ended'

        client.on 'error', (error) ->
          client.hasError = error
          callback error if callback?

        client.once 'ready', ->
          callback null, client
          callback = null

      destroy: (client) => client.end true
      validate: (client) => !client.hasError?

    return connectionPool

module.exports = Server
