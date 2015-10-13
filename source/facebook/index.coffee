async         = require 'async'
debug         = require('debug') 'loopback:satellizer:facebook'
request       = require 'request'
randomstring  = require 'randomstring'

common = require '../common'

module.exports = (options) ->

  version     = if options.facebook.version then options.facebook.version else 'v2.3'
  Common      = common options
  Model       = options.model

  credentials = options.facebook.credentials

  fetchAccessToken = (code, clientId, redirectUri, callback) ->
    debug 'fetchAccessToken'
    params =
      url: "https://graph.facebook.com/#{version}/oauth/access_token"
      qs:
        code: code
        client_id: clientId
        client_secret: credentials.private
        redirect_uri: redirectUri
      json: true
    if options.facebook.fields?.length > 0
      params.qs.fields = options.facebook.fields.join ','
    request.get params, (err, res, accessToken) ->
      if err
        debug JSON.stringify err
        return callback err
      if res.statusCode isnt 200
        err = new Error accessToken
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
    if options.facebook.fields?.length > 0
      params.qs.fields = options.facebook.fields.join ','
    request.get params, (err, res, profile) ->
      if err
        debug JSON.stringify err
        return callback err
      if res.statusCode isnt 200
        err = new Error profile
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
      query.where[options.facebook.mapping.email] = profile.email
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
    Common.map options.facebook.mapping, profile, tmp
    Model.create tmp, (err, created) ->
      debug JSON.stringify err if err
      return callback err, created

  link.existing = (profile, account, callback) ->
    debug 'link.existing', JSON.stringify(profile)
    if account.facebook and account[options.facebook.mapping.id] != profile.id
      err = new Error 'account_conflict'
      err.status = 409
      debug JSON.stringify err
      return callback err
    Common.map options.facebook.mapping, profile, account
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
      path: options.facebook.uri

  return
