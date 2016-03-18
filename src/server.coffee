_                     = require 'lodash'
RedisPooledJobManager = require 'meshblu-core-redis-pooled-job-manager'
mosca                 = require 'mosca'

class Server
  constructor: (options) ->
    {@port, redisUri, namespace, jobTimeoutSeconds, connectionPoolMaxConnections} = options
    {jobLogQueue, jobLogRedisUri, jobLogSampleRate} = options

    @jobManager = new RedisPooledJobManager
      jobLogIndexPrefix: 'metric:meshblu-server-mqtt'
      jobLogQueue: jobLogQueue
      jobLogRedisUri: jobLogRedisUri
      jobLogSampleRate: jobLogSampleRate
      jobLogType: 'meshblu-server-mqtt:request'
      jobTimeoutSeconds: jobTimeoutSeconds
      maxConnections: connectionPoolMaxConnections
      namespace: namespace
      redisUri: redisUri

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

module.exports = Server
