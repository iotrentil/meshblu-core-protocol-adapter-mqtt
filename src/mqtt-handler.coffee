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
      return @_emitError error if error?

  _emitError: (error) =>
    @server.publish ''


module.exports = MQTTHandler
