debug                 = require('debug')('meshblu-core-protocol-adapter-mqtt:server')
RedisPooledJobManager = require 'meshblu-core-redis-pooled-job-manager'
MultiHydrantFactory   = require 'meshblu-core-manager-hydrant/multi'
UuidAliasResolver     = require 'meshblu-uuid-alias-resolver'
MQTTHandler           = require './mqtt-handler'
RedisNS               = require '@octoblu/redis-ns'
redis                 = require 'ioredis'
mosca                 = require 'mosca'
_                     = require 'lodash'

class Server
  constructor: (options) ->
    {@moscaOptions, @redisUri, namespace, jobTimeoutSeconds, connectionPoolMaxConnections} = options
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
      redisUri: @redisUri

    uuidAliasClient = new RedisNS 'uuid-alias', redis.createClient(@redisUri)
    @uuidAliasResolver = new UuidAliasResolver
      cache: uuidAliasClient
      aliasServerUri: aliasServerUri

  authenticate: (client, username, password, callback) =>
    debug {username}
    hydrantClient = new RedisNS 'messages', redis.createClient(@redisUri)
    hydrant = new MultiHydrantFactory {client: hydrantClient, @uuidAliasResolver}
    hydrant.connect (error) =>
      return callback error if error?
      client.handler = new MQTTHandler {client, @jobManager, hydrant, @server}
      client.handler.authenticateClient username, password?.toString(), callback

  authorizeSubscribe: (client, topic, callback) =>
    authorize = false
    debug 'authorizeSubscribe:', "#{topic}": authorize
    return callback null, authorize

  authorizePublish: (client, topic, payload, callback) =>
    authorize = topic? and _.startsWith(topic,'meshblu/')
    debug 'authorizePublish:', "#{topic}": authorize
    return callback null, authorize

  start: (callback) =>
    debug 'starting with options', @moscaOptions
    @server = mosca.Server @moscaOptions
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
