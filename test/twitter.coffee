expect    = require('chai').expect
loopback  = require 'loopback'
nock      = require 'nock'
request   = require 'supertest'

component = require '../lib/index.js'

describe 'Twitter module', ->

  app     = null
  agent   = null
  Account = null

  first   = null
  second  = null
  third   = null

  beforeEach ->
    app     = require '../example/server/server.js'
    app.datasources.db.automigrate()
    agent   = request app
    Account = app.models.Account

  it 'should exist', ->
    expect(component.Twitter).to.exist

  it 'should populate model', ->
    expect(Account).to.exist
    expect(Account.twitter).to.exist

  profile =
    id: 'profile_id'
    screen_name: 'user_example'
    profile_image_url: 'http://picture.com/_normal'

  describe 'the first call', ->

    beforeEach ->
      first = nock 'https://api.twitter.com'
      .post '/oauth/request_token'
      .reply 200, 'oauth_token=oauth_token&oauth_verifier=oauth_verifier'

    it 'should return the token', (done) ->
      agent.post '/api/accounts/twitter'
      .end (err, res) ->
        expect(err).to.not.exist
        expect(res.statusCode).to.eql 200
        expect(res.body).to.exist
        expect(first.isDone()).to.eql true
        done err

  describe 'the second call', ->

    beforeEach ->
      second = nock 'https://api.twitter.com'
      .post '/oauth/access_token'
      .reply 200, 'oauth_token=oauth_token&screen_name=screen_name'

    beforeEach ->
      third = nock 'https://api.twitter.com'
      .get '/1.1/users/show.json?screen_name=screen_name'
      .reply 200, profile

    it 'should create the player', (done) ->
      agent.post '/api/accounts/twitter'
      .send
        oauth_token: 'oauthToken'
        oauth_verifier: 'oauthVerifier'
      .end (err, res) ->
        expect(err).to.not.exist
        expect(res.statusCode).to.eql 200
        expect(second.isDone()).to.eql true
        expect(third.isDone()).to.eql true
        done err
