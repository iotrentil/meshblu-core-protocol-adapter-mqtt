debug = require('debug')('meshblu-core-protocol-adapter-mqtt:handler')
async = require 'async'
_     = require 'lodash'

class MQTTHandler
  constructor: ({@client, @jobManager, @messengerFactory, @server}) ->
    @JOB_MAP =
      'meshblu.request': @handleMeshbluRequest

  initialize: (callback) =>
    return callback() unless @client?.auth?.uuid?

    @messenger = @messengerFactory.build()

    @messenger.on 'message', (channel, message) =>
      debug {channel, message}
      @_emitEvent 'message', message

    @messenger.on 'config', (channel, message) =>
      @_emitEvent 'config', message

    @messenger.connect (error) =>
      return callback error if error?

      async.each ['received', 'config', 'data'], (type, next) =>
        @messenger.subscribe {type, uuid: @client.auth.uuid}, next
      , callback

  handleMeshbluRequest: (packet) =>
    debug 'doing request...', packet
    try
      payload = JSON.parse packet.payload
    catch error
      return

    return unless payload?.job?
    return unless _.isObject payload.job.metadata
    payload.job.metadata.auth ?= @client.auth
    debug job: payload.job

    @jobManager.do 'request', 'response', payload.job, (error, response) =>
      debug 'response received:', response
      @_emitResponse response, payload.callbackId

  onPublished: (packet) =>
    debug 'onPublished'
    topic = packet.topic
    fn = @JOB_MAP[topic]
    return @_emitEvent('error', "Topic '#{topic}' is not valid") unless _.isFunction fn
    fn(packet)

  onClose: =>
    @messenger?.close()

  _emitResponse: (response, callbackId) =>
    response ?= metadata:
      code: 500
      status: 'null response from job manager'
    {topic, metadata, rawData:data} = response
    if metadata?.code >= 300
      topic = 'error'
      data = metadata?.status
    @_clientPublish {topic, data, callbackId}

  _emitEvent: (topic, data) =>
    @_clientPublish {topic, data}

  _clientPublish: (payload) =>
    payload = JSON.stringify payload
    @client.connection.publish {topic:'', payload}
    #@client.forward '', payload, {}, '', 0

module.exports = MQTTHandler
