_ = require 'lodash'
redis   = require 'ioredis'
RedisNS = require '@octoblu/redis-ns'
MessengerManager = require 'meshblu-core-manager-messenger'

class MessengerFactory
  constructor: ({@namespace, @redisUri, @uuidAliasResolver}) ->
    throw new Error('namespace is required') unless @namespace?
    throw new Error('redisUri is required') unless @redisUri?
    throw new Error('uuidAliasResolver is required') unless @uuidAliasResolver?

  build: =>
    client = new RedisNS @namespace, redis.createClient(@redisUri, dropBufferSupport: true)
    new MessengerManager {client, @uuidAliasResolver}

module.exports = MessengerFactory
