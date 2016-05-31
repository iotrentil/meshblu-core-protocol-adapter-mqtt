_                     = require 'lodash'
mosca                 = require 'mosca'
RedisPooledJobManager = require 'meshblu-core-redis-pooled-job-manager'
redis                 = require 'ioredis'
RedisNS               = require '@octoblu/redis-ns'
UuidAliasResolver     = require 'meshblu-uuid-alias-resolver'
MQTTHandler           = require './mqtt-handler'
MessengerFactory      = require './messenger-factory'

class Server
  constructor: (options) ->
    {@port, redisUri, namespace, jobTimeoutSeconds, connectionPoolMaxConnections} = options
    {jobLogQueue, jobLogRedisUri, jobLogSampleRate} = options
    {aliasServerUri} = options

    @jobManager = new RedisPooledJobManager
      jobLogIndexPrefix: 'metric:meshblu-core-protocol-adapter-mqtt'
      jobLogType: 'meshblu-core-protocol-adapter-mqtt:request'
      jobLogQueue: jobLogQueue
      jobLogRedisUri: jobLogRedisUri
      jobLogSampleRate: jobLogSampleRate
      jobTimeoutSeconds: jobTimeoutSeconds
      maxConnections: connectionPoolMaxConnections
      namespace: namespace
      redisUri: redisUri

    uuidAliasClient = new RedisNS 'uuid-alias', redis.createClient(redisUri, dropBufferSupport: true)
    uuidAliasResolver = new UuidAliasResolver
      cache: uuidAliasClient
      aliasServerUri: aliasServerUri

    @messengerFactory = new MessengerFactory {uuidAliasResolver, redisUri, namespace}

  address: =>
    {address: '0.0.0.0', port: @port}

  authenticate: (client, username, password, callback) =>
    auth =
      uuid:  username
      token: password?.toString()

    request = {metadata: {jobType: 'Authenticate', auth: auth}}

    @jobManager.do 'request', 'response', request, (error, response) =>
      return callback error if error?
      return callback new Error('unauthorized') unless response.metadata.code == 204
      client.auth = auth
      client.handler = new MQTTHandler {client, @jobManager, @messengerFactory, @server}
      client.handler.initialize (error) =>
        return callback error if error?
        callback null, true

  authorizeSubscribe: (client, topic, callback) =>
    return callback new Error('Client is unknown') unless client?
    return callback new Error('Client is unauthorized') unless client.auth?
    return callback null, true if topic == client.auth.uuid

    client.handler.subscribe topic, callback

  start: (callback) =>
    @server = mosca.Server {@port}

    @server.on 'ready', => @onReady callback
    @server.on 'clientConnected', @onConnect
    @server.on 'clientDisconnected', @onDisconnect
    @server.on 'published', @onPublished

  stop: (callback) =>
    @server.close callback

  onConnect: (client) =>

  onDisconnect: (client) =>
    client.handler.onClose()

  onPublished: (packet, client) =>
    return unless client?.handler?
    client.handler.onPublished packet

  onReady: (callback) =>
    @server.authenticate = @authenticate
    @server.authorizeSubscribe = @authorizeSubscribe
    callback()

module.exports = Server
