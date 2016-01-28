async         = require 'async'
debug         = require('debug') 'loopback:satellizer:google'
request       = require 'request'
randomstring  = require 'randomstring'

common = require '../common'

module.exports = (server, options) ->

  Common      = common server, options
  Model       = server.models[options.model]

  credentials = options.credentials

  fetchAccessToken = (code, clientId, redirectUri, callback) ->
    debug 'fetchAccessToken'
    request.post 'https://accounts.google.com/o/oauth2/token',
      form:
        code: code
        client_id: clientId
        client_secret: credentials.private
        redirect_uri: redirectUri
        grant_type: 'authorization_code'
      json: true
    , (err, res, accessToken) ->
      if err
        debug JSON.stringify err
        return callback err
      if res.statusCode isnt 200
        if accessToken and accessToken instanceof Object and accessToken.error
          accessToken.error.status = 500
          return callback accessToken.error  
        err = new Error JSON.stringify accessToken
        err.status = 500
        debug JSON.stringify err
        return callback err
      callback null, accessToken.access_token

  fetchProfile = (accessToken, callback) ->
    debug 'fetchProfile'
    request.get
      url: 'https://www.googleapis.com/plus/v1/people/me/openIdConnect'
      headers:
        Authorization: "Bearer #{accessToken}"
      json: true
    , (err, res, profile) ->
      if err
        debug JSON.stringify err
        return callback err
      if res.statusCode isnt 200
        if profile and profile instanceof Object and profile.error
          profile.error.status = 500
          return callback profile.error  
        err = new Error JSON.stringify profile
        err.status = 500
        debug JSON.stringify err
        return callback err
      callback null, profile

  link = (req, profile, callback) ->
    debug 'link'
    Common.current req, (err, found) ->
      if err
        debug err
        return callback err
      if found is null
        err = new Error 'not_an_account'
        err.status = 409
        debug err
        return callback err
      if found
        return link.existing profile, found, callback
      #
      query =
        where: {}
      query.where[options.mapping.email] = profile.email
      #
      Model.findOne query, (err, found) ->
        if err
          debug err
          return callback err
        return link.create profile, callback if not found
        return link.existing profile, found, callback

  link.create = (profile, callback) ->
    debug 'link.create', profile.id
    tmp =
      password: randomstring.generate()
    Common.map options.mapping, profile, tmp
    Model.create tmp, (err, created) ->
      debug err if err
      return callback err, created

  link.existing = (profile, account, callback) ->
    debug 'link.existing'
    if account.google and account[options.mapping.sub] != profile.sub
      err = new Error 'account_conflict'
      err.status = 409
      debug err
      return callback err
    Common.map options.mapping, profile, account
    account.save (err) ->
      debug err if err
      return callback err, account

  Model.google = (req, code, clientId, redirectUri, callback) ->
    debug 'google', "#{code}, #{clientId}, #{redirectUri}"
    async.waterfall [
      (done) ->
        fetchAccessToken code, clientId, redirectUri, done
      (accessToken, done) ->
        fetchProfile accessToken, done
      (profile, done) ->
        link req, profile, done
      (account, done) ->
        Common.authenticate account, done
    ], callback

  Model['google-get'] = (req, code, callback) ->
    debug 'google-get', code
    clientId = options.credentials.public
    if options.redirectUri
      redirectUri = options.redirectUri
    else
      redirectUri = "#{req.protocol}://#{req.get('host')}#{req.baseUrl}#{options.uri}"
    Model.google req, code, clientId, redirectUri, callback

  Model.remoteMethod 'google-get',
    accepts: [
      {
        arg: 'req'
        type: 'object'
        http:
          source: 'req'
      }
      {
        arg: 'code'
        type: 'string'
        http:
          source: 'query'
      }
    ]
    returns:
      arg: 'result'
      type: 'object'
      root: true
    http:
      verb: 'get'
      path: options.uri

  Model.remoteMethod 'google',
    accepts: [
      {
        arg: 'req'
        type: 'object'
        http:
          source: 'req'
      }
      {
        arg: 'code'
        type: 'string'
        http:
          source: 'form'
      }
      {
        arg: 'clientId'
        type: 'string'
        http:
          source: 'form'
      }
      {
        arg: 'redirectUri'
        type: 'string'
        http:
          source: 'form'
      }
    ]
    returns:
      arg: 'result'
      type: 'object'
      root: true
    http:
      verb: 'post'
      path: options.uri

  return
