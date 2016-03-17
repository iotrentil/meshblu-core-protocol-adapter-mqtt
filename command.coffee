commander    = require 'commander'
colors       = require 'colors'
PACKAGE_JSON = require './package.json'
Server       = require './src/server'

class Command
  constructor: ({@argv}) ->

  getOptions: =>
    commander
      .version PACKAGE_JSON.version
      .option '-p, --port <1883>', 'Port to listen on (MESHBLU_SERVER_MQTT_PORT)'
      .parse @argv

    return {
      port: parseInt(commander.port || process.env.MESHBLU_SERVER_MQTT_PORT || 1883)
    }

  panic: (error) =>
    console.error colors.red error.message
    console.error error.stack
    process.exit 1

  run: =>
    options = @getOptions()

    {port} = options
    @server = new Server {port}
    @server.start (error) =>
      @panic error if error?

      {address, port} = @server.address()
      console.log "Server running on #{address}:#{port}"

    process.on 'SIGTERM', @stop


  stop: =>
    console.log 'SIGTERM caught, exiting'
    @server.stop =>
      process.exit 0

    setTimeout =>
      console.log 'Server did not stop in time, exiting 0 manually'
      process.exit 0
    , 5000

command = new Command argv: process.argv
command.run()
