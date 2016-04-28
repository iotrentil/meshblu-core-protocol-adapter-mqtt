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
      payload = undefined

    return unless payload?.job?
    payload.job.metadata ?= {}
    return unless _.isObject payload.job.metadata
    payload.job.metadata.auth ?= @client.auth

    debug job: payload.job
    @jobManager.do 'request', 'response', payload.job, (error, response) =>
      debug 'response received:', response
      callbackInfo = payload.callbackInfo
      debug {callbackInfo}
      data = response.rawData
      if response.metadata.code >= 300
        data = response.metadata.status
        topic = 'error'
      reply = {topic, data, callbackInfo}

      # debug {reply}
      packet =
        topic: @client.id
        payload: JSON.stringify reply
          #_request: JSON.parse(originalPacket.payload.toString())
      debug {packet}
      @server.publish packet

      #@connection.publish(replyTo, reply) if replyTo?


  handleSendMessage: (packet) =>
    request =
      metadata:
        jobType: 'SendMessage'
        auth: @client.auth
      rawData: packet.payload

    @jobManager.do 'request', 'response', request, (error, response) =>
      return @_emitError packet, error if error?

  handleUpdate: (packet) =>
    data = JSON.parse packet.payload
    toUuid = data.uuid ? @client.auth.uuid
    callbackId = data.callbackId

    request =
      metadata:
        jobType: 'UpdateDevice'
        auth: @client.auth
        toUuid: toUuid
      data: $set: _.omit(data, 'uuid', 'callbackId')

    @jobManager.do 'request', 'response', request, (error, response) =>
      return @_emitError packet, error if error?
      return @_emitError packet, new Error('No Response') unless response?
      unless response.metadata.code == 204
        return @_emitError packet, new Error("update failed: #{response.metadata.status}")
      return @_emitTopic packet, 'update', {}

  handleWhoami: (packet) =>
    @_doJob 'GetDevice', 'whoami', (error, response) =>
      return @_emitError packet, error if error?
      return @_emitTopic packet, 'whoami', response

  onClose: =>
    @messenger?.close()

  onPublished: (packet) =>
    debug 'onPublished'
    topic = packet.topic
    fn = @JOB_MAP[topic]
    return @_emitError packet, new Error("Topic '#{topic}' is not valid") unless _.isFunction fn
    fn(packet)

  subscribe: (uuid, callback) =>
    request =
      metadata:
        jobType: 'GetAuthorizedSubscriptionTypes'
        auth: @client.auth
        toUuid: uuid
      data: ['config', 'data', 'received']

    @jobManager.do 'request', 'response', request, (error, response) =>
      return callback error if error?
      return callback null, false unless response.metadata.code == 204
      data = JSON.parse response.rawData
      async.each data.types, (type, next) =>
        @messenger.subscribe {type, uuid: uuid}, next
      , (error) =>
        return callback error if error?
        callback null, true

  _doJob: (jobType, eventName, callback) =>
    request =
      metadata:
        jobType: jobType
        auth: @client.auth
        toUuid: @client.auth.uuid

    @jobManager.do 'request', 'response', request, (error, response) =>
      return callback error if error?
      return callback new Error('No Response') unless response?
      return callback new Error("#{eventName} failed: #{response.metadata.status}") unless response.metadata.code == 200
      return callback null, JSON.parse(response.rawData)

  _emitError: (originalPacket, error) =>
    @_emitTopic originalPacket, 'error', message: error.message

  _emitEvent: (topic, payload) =>
    packet =
      topic: @client.id
      payload: JSON.stringify
        topic: topic
        data: payload
    @server.publish packet

  _emitTopic: (originalPacket, topic, payload) =>
    packet =
      topic: @client.auth.uuid
      payload: JSON.stringify
        topic: topic
        data: payload
        _request: JSON.parse(originalPacket.payload.toString())
    @server.publish packet

module.exports = MQTTHandler
