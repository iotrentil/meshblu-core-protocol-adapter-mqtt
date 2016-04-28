_                     = require 'lodash'
mosca                 = require 'mosca'
RedisPooledJobManager = require 'meshblu-core-redis-pooled-job-manager'
redis                 = require 'ioredis'
RedisNS               = require '@octoblu/redis-ns'
UuidAliasResolver     = require 'meshblu-uuid-alias-resolver'
MQTTHandler           = require './mqtt-handler'
MessengerFactory      = require './messenger-factory'
debug                 = require('debug')('meshblu-core-protocol-adapter-mqtt:server')

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
    debug {username, id: client.id}
    clientPrefix = username
    clientPrefix ?= 'guest'
    validClientId = client.id.search(new RegExp "^#{clientPrefix}[\.\/]") == 0
    return callback new Error('invalid client id') if !validClientId
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
    return callback new Error('Client is unknown') unless client?
    {uuid, token} = client.auth or {}
    result = (topic == client.id) or (uuid? and topic == "#{uuid}.firehose")
    debug "topic authorization for #{topic} = #{result}"
    return callback null, result

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
    client?.handler?.onClose?()

  onPublished: (packet, client) =>
    debug 'server.onPublished', {packet}
    return unless client?.handler?
    client.handler.onPublished packet

  onReady: (callback) =>
    @server.authenticate = @authenticate
    @server.authorizeSubscribe = @authorizeSubscribe
    callback()

module.exports = Server
