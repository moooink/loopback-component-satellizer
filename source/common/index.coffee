debug = console.log

module.exports = (config) ->

  Model = options.model

  authenticate = (account, callback) ->
    debug 'authenticate', account.email
    ttl = 1000*60*60*24*7
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

  return {
    authenticate: authenticate
    current:      current
  }
