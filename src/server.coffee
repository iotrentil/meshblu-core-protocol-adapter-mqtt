debug                 = require('debug')('meshblu-core-protocol-adapter-mqtt:server')
RedisPooledJobManager = require 'meshblu-core-redis-pooled-job-manager'
UuidAliasResolver     = require 'meshblu-uuid-alias-resolver'
MessengerFactory      = require './messenger-factory'
MQTTHandler           = require './mqtt-handler'
RedisNS               = require '@octoblu/redis-ns'
redis                 = require 'ioredis'
mosca                 = require 'mosca'
_                     = require 'lodash'

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

    uuidAliasClient = new RedisNS 'uuid-alias', redis.createClient(redisUri)
    uuidAliasResolver = new UuidAliasResolver
      cache: uuidAliasClient
      aliasServerUri: aliasServerUri

    @messengerFactory = new MessengerFactory {uuidAliasResolver, redisUri, namespace}

  address: =>
    {address: '0.0.0.0', port: @port}

  authenticate: (client, username, password, callback) =>
    debug {username}
    return @initializeClient(client, callback) unless username?

    auth =
      uuid:  username
      token: password?.toString()

    request = {metadata: {jobType: 'Authenticate', auth: auth}}

    @jobManager.do 'request', 'response', request, (error, response) =>
      return callback error if error?
      return callback new Error('unauthorized') unless response.metadata.code == 204
      client.auth = auth
      @initializeClient client, callback

  initializeClient: (client, callback) =>
    client.handler = new MQTTHandler {client, @jobManager, @messengerFactory, @server}
    client.handler.initialize (error) =>
      return callback error if error?
      callback null, true

  authorizeSubscribe: (client, topic, callback) =>
    debug 'authorizeSubscribe:', {topic}
    return callback null, false

  authorizePublish: (client, topic, payload, callback) =>
    authorize = topic? and topic.startsWith('meshblu.')
    debug 'authorizePublish:', "#{topic}": authorize
    return callback null, authorize

  start: (callback) =>
    options = {
      interfaces: [{type:'mqtt'}, {type:'http'}]
    }
    @server = mosca.Server options # {@port}

    @server.on 'ready', => @onReady callback
    @server.on 'clientConnected', @onConnect
    @server.on 'clientDisconnected', @onDisconnect
    @server.on 'published', @onPublished

  stop: (callback) =>
    @server.close callback

  onConnect: (client) =>

  onDisconnect: (client) =>
    client?.handler?.onClose?()

  onPublished: (packet, client) =>
    debug 'server.onPublished', {packet}
    return unless client?.handler?
    client.handler.onPublished packet

  onReady: (callback) =>
    @server.authenticate = @authenticate
    @server.authorizeSubscribe = @authorizeSubscribe
    @server.authorizePublish = @authorizePublish
    callback()

module.exports = Server
