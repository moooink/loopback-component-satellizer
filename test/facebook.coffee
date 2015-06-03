expect    = require('chai').expect
loopback  = require 'loopback'
nock      = require 'nock'
request   = require 'supertest'

component = require '../lib/index.js'

describe 'Facebook module', ->

  app     = null
  agent   = null
  Account = null

  beforeEach ->
    app     = require '../example/server/server.js'
    agent   = request app
    Account = app.models.Account

  it 'should exist', ->
    expect(component.Facebook).to.exist

  it 'should populate model', ->
    expect(Account).to.exist
    expect(Account.facebook).to.exist

  describe 'call to loopback method', ->

    first = null
    second = null

    answer = null

    profile =
      id: 'profile_id'
      email: 'user@example.com'
      first_name: 'firstName'
      last_name: 'lastName'
      birthday: new Date()
      gender: 'male'

    beforeEach ->
      first = nock 'https://graph.facebook.com'
      .get '/v2.3/oauth/access_token?code=this_is_a_code&client_id=this_is_a_client_id&client_secret=this_is_a_private_key&redirect_uri=this_is_the_uri'
      .reply 200,
        token: 'my_wonderfull_token'

    beforeEach ->
      second = nock 'https://graph.facebook.com'
      .get '/v2.3/me?token=my_wonderfull_token'
      .reply 200, profile

    beforeEach (done) ->
      agent.post '/api/accounts/facebook'
      .send
        code: 'this_is_a_code'
        clientId: 'this_is_a_client_id'
        redirectUri: 'this_is_the_uri'
      .end (err, res) ->
        answer =
          err: err
          res: res
        done()

    it 'should call facebook twice and return profile', ->
      expect(first.isDone()).to.eql true
      expect(second.isDone()).to.eql true

    it 'should return a token', ->
      expect(answer.err).to.not.exist
      expect(answer.res.statusCode).to.eql 200
      expect(answer.res.body).to.have.property 'id'
      expect(answer.res.body).to.have.property 'userId'
      # Allow satellizer to store its token
      expect(answer.res.body).to.have.property 'token'
      expect(answer.res.body).to.have.property 'ttl'

    it 'should create the account', (done) ->
      app.models.Account.findOne
        where:
          email: 'user@example.com'
      , (err, found) ->
        expect(err).to.not.exist
        expect(found).to.exist
        expect(found.facebook).to.eql 'profile_id'
        done err
