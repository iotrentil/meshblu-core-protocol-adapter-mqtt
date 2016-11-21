_                       = require 'lodash'
mosca                   = require 'mosca'
Redis                   = require 'ioredis'
RedisNS                 = require '@octoblu/redis-ns'
UuidAliasResolver       = require 'meshblu-uuid-alias-resolver'
MQTTHandler             = require './mqtt-handler'
MessengerManagerFactory = require 'meshblu-core-manager-messenger/factory'
colors                  = require 'colors'
JobLogger               = require 'job-logger'
{ JobManagerRequester } = require 'meshblu-core-job-manager'

class Server
  constructor: (options) ->
    {
      @disableLogging
      @port
      @aliasServerUri
      @redisUri
      @cacheRedisUri
      @firehoseRedisUri
      @namespace
      @jobTimeoutSeconds
      @maxConnections
      @jobLogRedisUri
      @jobLogQueue
      @jobLogSampleRate
      @requestQueueName
      @responseQueueName
    } = options
    @panic 'missing @cacheRedisUri', 2 unless @cacheRedisUri?
    @panic 'missing @redisUri', 2 unless @redisUri?
    @panic 'missing @firehoseRedisUri', 2 unless @firehoseRedisUri?
    @panic 'missing @jobLogQueue', 2 unless @jobLogQueue?
    @panic 'missing @jobLogRedisUri', 2 unless @jobLogRedisUri?
    @panic 'missing @jobLogSampleRate', 2 unless @jobLogSampleRate?
    @panic 'missing @requestQueueName', 2 unless @requestQueueName?
    @panic 'missing @responseQueueName', 2 unless @responseQueueName?

    uuidAliasClient = new RedisNS 'uuid-alias', new Redis @cacheRedisUri, dropBufferSupport: true
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

    @jobManager.do request, (error, response) =>
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
    jobLogger = new JobLogger
      client: new Redis @jobLogRedisUri, dropBufferSupport: true
      indexPrefix: 'metric:meshblu-core-protocol-adapter-mqtt'
      type: 'meshblu-core-protocol-adapter-mqtt:request'
      jobLogQueue: @jobLogQueue

    @jobManager = new JobManagerRequester {
      @namespace
      @redisUri
      maxConnections: 2
      @jobTimeoutSeconds
      @jobLogSampleRate
      @requestQueueName
      @responseQueueName
      queueTimeoutSeconds: @jobTimeoutSeconds
    }

    @jobManager.once 'error', (error) =>
      @panic 'fatal job manager error', 1, error

    @jobManager._do = @jobManager.do
    @jobManager.do = (request, callback) =>
      @jobManager._do request, (error, response) =>
        jobLogger.log { error, request, response }, (jobLoggerError) =>
          return callback jobLoggerError if jobLoggerError?
          callback error, response

    @jobManager.start (error) =>
      return callback error if error?

      @server = mosca.Server {@port}

      @server.on 'ready', => @onReady callback
      @server.on 'clientConnected', @onConnect
      @server.on 'clientDisconnected', @onDisconnect
      @server.on 'published', @onPublished

  stop: (callback) =>
    @jobManager.stop =>
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
