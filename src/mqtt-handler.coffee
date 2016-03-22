_ = require 'lodash'

class MQTTHandler
  constructor: ({@client, @jobManager, @server}) ->

    @JOB_MAP =
      'message': @handleSendMessage
      'update':  @handleUpdate

  handleSendMessage: (packet) =>
    request =
      metadata:
        jobType: 'SendMessage'
        auth: @client.auth
      rawData: packet.payload

    @jobManager.do 'request', 'response', request, (error, response) =>
      return @_emitError packet.payload, error if error?

  handleUpdate: (packet) =>
    data = JSON.parse packet.payload
    toUuid = data.uuid ? @client.auth.uuid

    request =
      metadata:
        jobType: 'UpdateDevice'
        auth: @client.auth
        toUuid: toUuid
      data: _.omit(data, 'uuid')

    @jobManager.do 'request', 'response', request, (error, response) =>
      return @_emitError packet.payload, error if error?
      return @_emitError packet.payload, new Error('No Response') unless response?
      # unless response.code == 204
      return @_emitError packet.payload, new Error("Update failed: #{response.metadata.status}")

  onPublished: (packet) =>
    topic = packet.topic
    fn = @JOB_MAP[topic]
    return @_emitError packet, new Error("Topic '#{topic}' is not valid") unless _.isFunction fn
    fn(packet)

  _emitError: (originalPacket, error) =>
    packet =
      topic: @client.auth.uuid
      payload: JSON.stringify
        topic: 'error'
        payload:
          message: error.message
        _request: originalPacket.payload
    @server.publish packet


module.exports = MQTTHandler
