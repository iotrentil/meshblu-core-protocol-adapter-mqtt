_ = require 'lodash'
async = require 'async'

class MQTTHandler
  constructor: ({@client, @jobManager, @messengerFactory, @server}) ->
    @JOB_MAP =
      'generateAndStoreToken': @handleGenerateAndStoreToken
      'getPublicKey':          @handleGetPublicKey
      'message':               @handleSendMessage
      'resetToken':            @handleResetToken
      'update':                @handleUpdate
      'whoami':                @handleWhoami

  initialize: (callback) =>  
    @messenger = @messengerFactory.build()

    @messenger.on 'message', (channel, message) =>
      @_emitEvent 'message', channel, message

    @messenger.on 'config', (channel, message) =>
      @_emitEvent 'config', channel, message

    @messenger.on 'error', (error) =>
      @messenger.close()

    @messenger.connect (error) =>
      return callback error if error?
      async.each ['received', 'config', 'data'], (type, next) =>
        @messenger.subscribe {type, uuid: @client.auth.uuid}, next
      , callback

  handleGenerateAndStoreToken: (packet) =>
    @_doJob 'CreateSessionToken', 'generateAndStoreToken', (error, response) =>
      return @_emitError packet, error if error?
      return @_emitTopic packet, 'generateAndStoreToken', response

  handleGetPublicKey: (packet) =>
    @_doJob 'GetDevicePublicKey', 'getPublicKey', (error, response) =>
      return @_emitError packet, error if error?
      return @_emitTopic packet, 'getPublicKey', response

  handleResetToken: (packet) =>
    @_doJob 'ResetToken', 'resetToken', (error, response) =>
      return @_emitError packet, error if error?
      return @_emitTopic packet, 'resetToken', response

  handleSendMessage: (packet) =>
    request =
      metadata:
        jobType: 'SendMessage'
        auth: @client.auth
      rawData: packet.payload

    @jobManager.do request, (error, response) =>
      return @_emitError packet, error if error?

  handleUpdate: (packet) =>
    try
      data = JSON.parse packet.payload
      toUuid = data.uuid ? @client.auth.uuid
      callbackId = data.callbackId

      request =
        metadata:
          jobType: 'UpdateDevice' 
          auth: @client.auth
          toUuid: toUuid
        data: $set: _.omit(data, 'uuid', 'callbackId')

      @jobManager.do request, (error, response) =>
        return @_emitError packet, error if error?
        return @_emitError packet, new Error('No Response') unless response?
        unless response.metadata.code == 204
          return @_emitError packet, new Error("update failed: #{response.metadata.status}")
        return @_emitTopic packet, 'update', {}
    catch e
      packet = {}
      packet.payload = {}
      return @_emitError {}, new Error("handleUpdate Json parse Error: #{e}")


  handleWhoami: (packet) =>
    @_doJob 'GetDevice', 'whoami', (error, response) =>
      return @_emitError packet, error if error?
      return @_emitTopic packet, 'whoami', response

  onClose: =>
    @messenger?.close()

  onPublished: (packet) =>
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
      data: { types: ['config', 'data', 'received', 'broadcast'] }

    @jobManager.do request, (error, response) =>
      return callback error if error?
      return callback null, false unless response.metadata.code == 204
      data = JSON.parse response.rawData
      console.log "subscribe[#{uuid}] : " + JSON.stringify data.types
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

    @jobManager.do request, (error, response) =>
      return callback error if error?
      return callback new Error('No Response') unless response?
      return callback new Error("#{eventName} failed: #{response.metadata.status}") unless response.metadata.code == 200
      return callback null, JSON.parse(response.rawData)

  _emitError: (originalPacket, error) =>
    @_emitTopic originalPacket, 'error', message: error.message

  _emitEvent: (topic, channel, payload) =>
    uuid = _.last channel.split /:/
    packet =
      topic: uuid
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
