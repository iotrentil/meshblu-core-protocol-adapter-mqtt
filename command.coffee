commander    = require 'commander'
colors       = require 'colors'
PACKAGE_JSON = require './package.json'
Server       = require './src/server'

class Command
  constructor: ->
    @serverOptions =
      port:                         process.env.PORT || 1883
      aliasServerUri:               process.env.ALIAS_SERVER_URI
      redisUri:                     process.env.REDIS_URI
      firehoseRedisUri:             process.env.FIREHOSE_REDIS_URI
      namespace:                    process.env.NAMESPACE || 'meshblu'
      jobTimeoutSeconds:            parseInt(process.env.JOB_TIMEOUT_SECONDS || 30)
      maxConnections:               parseInt(process.env.CONNECTION_POOL_MAX_CONNECTIONS || 100)
      disableLogging:               process.env.DISABLE_LOGGING == "true"
      jobLogRedisUri:               process.env.JOB_LOG_REDIS_URI
      jobLogQueue:                  process.env.JOB_LOG_QUEUE
      jobLogSampleRate:             parseFloat(process.env.JOB_LOG_SAMPLE_RATE)

  panic: (error) =>
    console.error colors.red error.message
    console.error error.stack
    process.exit 1

  run: =>
    @panic new Error('Missing required environment variable: REDIS_URI') if _.isEmpty @serverOptions.redisUri
    @panic new Error('Missing required environment variable: FIREHOSE_REDIS_URI') if _.isEmpty @serverOptions.firehoseRedisUri
    @panic new Error('Missing required environment variable: JOB_LOG_REDIS_URI') if _.isEmpty @serverOptions.jobLogRedisUri
    @panic new Error('Missing required environment variable: JOB_LOG_QUEUE') if _.isEmpty @serverOptions.jobLogQueue
    @panic new Error('Missing required environment variable: JOB_LOG_SAMPLE_RATE') unless _.isNumber @serverOptions.jobLogSampleRate

    @server = new Server @serverOptions
    @server.run (error) =>
      return @panic error if error?

      {address, port} = @server.address()
      console.log "Server running on #{address}:#{port}"

    process.on 'SIGTERM', =>
      console.log 'SIGTERM caught, exiting'
      server.stop =>
        process.exit 0

      setTimeout =>
        console.log 'Server did not stop in time, exiting 0 manually'
        process.exit 0
      , 5000

command = new Command argv: process.argv
command.run()
