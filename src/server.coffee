_          = require 'lodash'
JobManager = require 'meshblu-core-job-manager'
RedisNS    = require '@octoblu/redis-ns'
redis      = require 'redis'
mosca      = require 'mosca'

class Server
  constructor: ({@port, redisUri, namespace, jobTimeoutSeconds}) ->
    @jobManager = new JobManager
      client: new RedisNS namespace, redis.createClient(redisUri)
      timeoutSeconds: jobTimeoutSeconds

  address: =>
    {address: '0.0.0.0', port: @port}

  authenticate: (client, username, password, callback) =>
    job =
      metadata:
        auth: {uuid: username, token: password?.toString()}
        jobType: 'Authenticate'

    @jobManager.do 'request', 'response', job, (error, response) =>
      return callback error if error?
      return callback new Error('unauthorized') unless response.metadata.code == 204
      callback null, true

  start: (callback) =>
    @server = mosca.Server {@port}

    @server.on 'ready', => @onReady callback
    @server.on 'clientConnected', @onConnect

  stop: (callback) =>
    @server.close callback

  onConnect: (client) =>

  onReady: (callback) =>
    @server.authenticate = @authenticate
    callback()

module.exports = Server
