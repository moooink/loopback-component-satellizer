async         = require 'async'
debug         = require('debug') 'loopback:satellizer:twitter'
qs            = require 'querystring'
request       = require 'request'
randomstring  = require 'randomstring'

common = require '../common'

module.exports = (options) ->

  Common      = common options
  Model       = options.model

  credentials = options.twitter.credentials
  callbackUrl = options.twitter.callbackUrl

  handleFirstRequest = (callback) ->
    request.post
      url: 'https://api.twitter.com/oauth/request_token'
      oauth:
        consumer_key: credentials.public
        consumer_secret: credentials.private
    , (err, res, body) ->
      return callback err if err
      callback null, qs.parse body

  fetchAccessToken = (oauthToken, oauthVerifier, callback) ->
    request.post
      url: 'https://api.twitter.com/oauth/access_token'
      oauth:
        consumer_key: credentials.public
        consumer_secret: credentials.private
        token: oauthToken
        verifier: oauthVerifier
    , (err, res, accessToken) ->
      return callback err if err
      callback null, qs.parse accessToken

  fetchProfile = (accessToken, callback) ->
    debug 'fetchProfile'
    request.get
      url: 'https://api.twitter.com/1.1/users/show.json?screen_name=' + accessToken.screen_name
      oauth:
        consumer_key: credentials.public
        consumer_secret: credentials.private
        oauth_token: accessToken.oauth_token
      json: true
    , (err, res, profile) ->
      return callback err if err
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
      query.where[options.twitter.mapping.id] = profile.id
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
      email: "#{profile.id}@twitter.com"
      password: randomstring.generate()
    Common.map options.twitter.mapping, profile, tmp
    Model.create tmp, (err, created) ->
      debug err if err
      return callback err, created

  link.existing = (profile, account, callback) ->
    debug 'link.existing'
    if account[options.twitter.mapping.id] and account[options.twitter.mapping.id] != profile.id
      err = new Error 'account_conflict'
      err.status = 409
      debug err
      return callback err
    Common.map options.twitter.mapping, profile, account
    account.save (err) ->
      debug err if err
      return callback err, account

  Model.twitter = (req, oauthToken, oauthVerifier, callback) ->
    debug "#{oauthToken}, #{oauthVerifier}"
    # Initial request for satellizer
    return handleFirstRequest callback if not oauthToken or not oauthVerifier
    async.waterfall [
      (done) ->
        fetchAccessToken oauthToken, oauthVerifier, done
      (accessToken, done) ->
        fetchProfile accessToken, done
      (profile, done) ->
        link req, profile, done
      (account, done) ->
        Common.authenticate account, done
    ], callback

  Model.remoteMethod 'twitter',
    accepts: [
      {
        arg: 'req'
        type: 'object'
        http:
          source: 'req'
      }
      {
        arg: 'oauth_token'
        type: 'string'
        http:
          source: 'form'
      }
      {
        arg: 'oauth_verifier'
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
      path: options.twitter.uri

  return
