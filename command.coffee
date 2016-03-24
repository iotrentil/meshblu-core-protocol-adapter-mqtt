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

    throw new Error('env JOB_LOG_QUEUE not set') unless process.env.JOB_LOG_QUEUE
    throw new Error('env JOB_LOG_REDIS_URI not set') unless process.env.JOB_LOG_REDIS_URI
    throw new Error('env JOB_LOG_SAMPLE_RATE not set') unless process.env.JOB_LOG_SAMPLE_RATE
    throw new Error('env JOB_TIMEOUT_SECONDS not set') unless process.env.JOB_TIMEOUT_SECONDS
    throw new Error('env MAX_CONNECTIONS not set') unless process.env.MAX_CONNECTIONS
    throw new Error('env NAMESPACE not set') unless process.env.NAMESPACE
    throw new Error('env REDIS_URI not set') unless process.env.REDIS_URI

    return {
      port: parseInt(commander.port || process.env.MESHBLU_SERVER_MQTT_PORT || 1883)
      jobLogQueue: process.env.JOB_LOG_QUEUE
      jobLogRedisUri: process.env.JOB_LOG_REDIS_URI
      jobLogSampleRate: parseFloat process.env.JOB_LOG_SAMPLE_RATE
      jobTimeoutSeconds: parseInt process.env.JOB_TIMEOUT_SECONDS
      connectionPoolMaxConnections: parseInt process.env.MAX_CONNECTIONS
      namespace: process.env.NAMESPACE
      redisUri: process.env.REDIS_URI
    }

  panic: (error) =>
    console.error colors.red error.message
    console.error error.stack
    process.exit 1

  run: =>
    @server = new Server @getOptions()
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
