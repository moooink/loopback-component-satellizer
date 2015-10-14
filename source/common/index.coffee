debug         = require('debug') 'loopback:satellizer:common'

module.exports = (server, options) ->

  Model = server.models[options.model]

  authenticate = (account, callback) ->
    ttl = account.constructor.settings.maxTTL
    account.createAccessToken ttl, (err, token) ->
      return callback err if err
      Model.app.models.AccessToken.find {}, (err, list) ->
        token.token = token.id
        callback null, token

  current = (req, callback) ->
    debug 'current'
    return callback null, false if not req.headers.authorization
    AccessToken = Model.app.models.AccessToken
    AccessToken.findForRequest req, (err, accessToken) ->
      if err
        Account.app.logger.error err
        return callback err
      return callback null, false if not accessToken
      Model.findById accessToken.userId, callback

  map = (config, source, destination) ->
    for key, value of config
      if key of source
        destination[value] = destination[value] or source[key]

  return {
    authenticate: authenticate
    current:      current
    map:          map
  }
