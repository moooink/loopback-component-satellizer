async         = require 'async'
debug         = require('debug') 'loopback:satellizer:facebook'
request       = require 'request'
randomstring  = require 'randomstring'

common = require '../common'

module.exports = (server, options) ->

  version     = if options.version then options.version else 'v2.3'
  Common      = common server, options
  Model       = server.models[options.model]

  fetchAccessToken = (code, clientId, redirectUri, callback) ->
    debug 'fetchAccessToken'
    params =
      url: "https://graph.facebook.com/#{version}/oauth/access_token"
      qs:
        code: code
        client_id: clientId
        client_secret: options.credentials.private
        redirect_uri: redirectUri
      json: true
    if options.fields?.length > 0
      params.qs.fields = options.fields.join ','
    request.get params, (err, res, accessToken) ->
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
      callback null, accessToken

  fetchProfile = (accessToken, callback) ->
    debug 'fetchProfile'
    params =
      url: "https://graph.facebook.com/#{version}/me"
      qs: accessToken
      json: true
    if options.fields?.length > 0
      params.qs.fields = options.fields.join ','
    request.get params, (err, res, profile) ->
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
    debug 'link', JSON.stringify(profile)
    Common.current req, (err, found) ->
      if err
        debug JSON.stringify err
        return callback err
      if found is null
        err = new Error 'not_an_account'
        err.status = 409
        debug JSON.stringify err
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
          debug JSON.stringify err
          return callback err
        return link.create profile, callback if not found
        return link.existing profile, found, callback

  link.create = (profile, callback) ->
    debug 'link.create', JSON.stringify(profile)
    tmp =
      password: randomstring.generate()
    Common.map options.mapping, profile, tmp
    Model.create tmp, (err, created) ->
      debug JSON.stringify err if err
      return callback err, created

  link.existing = (profile, account, callback) ->
    debug 'link.existing', JSON.stringify(profile)
    if account.facebook and account[options.mapping.id] != profile.id
      err = new Error 'account_conflict'
      err.status = 409
      debug JSON.stringify err
      return callback err
    Common.map options.mapping, profile, account
    account.save (err) ->
      debug JSON.stringify err if err
      return callback err, account

  Model.facebook = (req, code, clientId, redirectUri, callback) ->
    debug "#{code}, #{clientId}, #{redirectUri}"
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

  Model['facebook-get'] = (req, code, callback) ->
    debug 'facebook-get', code
    clientId = options.credentials.public
    if options.redirectUri
      redirectUri = options.redirectUri
    else
      redirectUri = "#{req.protocol}://#{req.get('host')}#{req.baseUrl}#{options.uri}"
    Model.facebook req, code, clientId, redirectUri, callback

  Model.remoteMethod 'facebook-get',
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


  Model.remoteMethod 'facebook',
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
