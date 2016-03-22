class MQTTHandler
  constructor: ({@client, @jobManager, @server}) ->

  @JOB_MAP:
    'message': 'SendMessage'

  onPublished: (packet) =>
    request =
      metadata:
        jobType: MQTTHandler.JOB_MAP[packet.topic]
        auth: @client.auth
      rawData: packet.payload

    @jobManager.do 'request', 'response', request, (error, response) =>
      return @_emitError packet.payload, error if error?

  _emitError: (payload, error) =>
    message =
      topic: 'error'
      payload:
        message: error.message
      _request: payload
    @server.publish @client.auth.uuid, message


module.exports = MQTTHandler
