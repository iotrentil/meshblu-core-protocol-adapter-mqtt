_                       = require 'lodash'
mosca                   = require 'mosca'
RedisPooledJobManager   = require 'meshblu-core-redis-pooled-job-manager'
redis                   = require 'ioredis'
RedisNS                 = require '@octoblu/redis-ns'
UuidAliasResolver       = require 'meshblu-uuid-alias-resolver'
MQTTHandler             = require './mqtt-handler'
MessengerManagerFactory = require 'meshblu-core-manager-messenger/factory'
colors                  = require 'colors'

class Server
  constructor: (options) ->
    {
      @disableLogging
      @port
      @aliasServerUri
      @redisUri
      @firehoseRedisUri
      @namespace
      @jobTimeoutSeconds
      @maxConnections
      @jobLogRedisUri
      @jobLogQueue
      @jobLogSampleRate
    } = options
    @panic 'missing @jobLogQueue', 2 unless @jobLogQueue?
    @panic 'missing @jobLogRedisUri', 2 unless @jobLogRedisUri?
    @panic 'missing @jobLogSampleRate', 2 unless @jobLogSampleRate?

    uuidAliasClient = new RedisNS 'uuid-alias', redis.createClient(@redisUri, dropBufferSupport: true)
    uuidAliasResolver = new UuidAliasResolver
      cache: uuidAliasClient
      aliasServerUri: @aliasServerUri

    @messengerFactory = new MessengerManagerFactory {uuidAliasResolver, @namespace, redisUri: @firehoseRedisUri}

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

  panic: (message, exitCode, error) =>
    error ?= new Error('generic error')
    console.error colors.red message
    console.error error?.stack
    process.exit exitCode

  run: (callback) =>
    @jobManager = new RedisPooledJobManager {
      jobLogIndexPrefix: 'metric:meshblu-core-protocol-adapter-mqtt'
      jobLogType: 'meshblu-core-protocol-adapter-mqtt:request'
      @jobTimeoutSeconds
      @jobLogQueue
      @jobLogRedisUri
      @jobLogSampleRate
      @maxConnections
      @redisUri
      @namespace
    }

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
