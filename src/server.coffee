_                     = require 'lodash'
RedisPooledJobManager = require 'meshblu-core-redis-pooled-job-manager'
mosca                 = require 'mosca'
MQTTHandler           = require './mqtt-handler'

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
    auth =
      uuid:  username
      token: password?.toString()

    job = {metadata: {jobType: 'Authenticate', auth: auth}}

    @jobManager.do 'request', 'response', job, (error, response) =>
      return callback error if error?
      return callback new Error('unauthorized') unless response.metadata.code == 204
      client.auth = auth
      client.handler = new MQTTHandler {client, @jobManager, @server}
      callback null, true

  authorizeSubscribe: (client, topic, callback) =>
    return callback new Error('Client is unknown') unless client?
    return callback new Error('Client is unauthorized') unless client.auth?
    return callback null, (topic == client.auth.uuid)

  start: (callback) =>
    @server = mosca.Server {@port}

    @server.on 'ready', => @onReady callback
    @server.on 'clientConnected', @onConnect
    @server.on 'published', @onPublished

  stop: (callback) =>
    @server.close callback

  onConnect: (client) =>

  onPublished: (packet, client) =>
    return unless client?.handler?
    client.handler.onPublished packet

  onReady: (callback) =>
    @server.authenticate = @authenticate
    @server.authorizeSubscribe = @authorizeSubscribe
    callback()

module.exports = Server
