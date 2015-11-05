expect    = require('chai').expect
loopback  = require 'loopback'
nock      = require 'nock'
request   = require 'supertest'

component = require '../lib/index.js'

describe 'Google module', ->

  app     = null
  agent   = null
  Account = null

  beforeEach ->
    app     = require '../example/server/server.js'
    app.datasources.db.automigrate()
    agent   = request app
    Account = app.models.Account

  it 'should populate model', ->
    expect(Account).to.exist
    expect(Account.google).to.exist

  describe 'call to loopback method', ->

    first = null
    second = null

    answer = null

    profile =
      sub: 'profile_id'
      email: 'user@example.com'
      given_name: 'my_first_name'
      family_name: 'my_last_name'
      birthday: new Date()
      gender: 'male'

    beforeEach ->
      first = nock 'https://accounts.google.com'
      .post '/o/oauth2/token',
        code: 'this_is_a_code'
        client_id: 'this_is_a_client_id'
        client_secret: 'this_is_a_private_key'
        redirect_uri: 'this_is_the_uri'
        grant_type: 'authorization_code'
      .reply 200,
        token:
          token: 'my_wonderfull_token'

    beforeEach ->
      second = nock 'https://www.googleapis.com'
      .get '/plus/v1/people/me/openIdConnect'
      .reply 200, profile

    describe 'with post verb', ->

      beforeEach (done) ->
        agent.post '/api/accounts/google'
        .send
          code: 'this_is_a_code'
          clientId: 'this_is_a_client_id'
          redirectUri: 'this_is_the_uri'
        .end (err, res) ->
          answer =
            err: err
            res: res
          done()

      it 'should call google twice and return profile', ->
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
        app.models.Account.count email: 'user@example.com', (err, nb) ->
          expect(err).to.not.exist
          expect(nb).to.eql 1
          done err

      it 'should map the profile in the account', (done) ->
        app.models.Account.findOne
          where:
            email: 'user@example.com'
        , (err, found) ->
          expect(err).to.not.exist
          expect(found).to.exist
          expect(found.google).to.eql profile.sub
          expect(found.firstName).to.eql profile.given_name
          expect(found.lastName).to.eql profile.family_name
          expect(found.gender).to.eql profile.gender
          done err

    describe 'with get verb', ->

      beforeEach (done) ->
        agent.get '/api/accounts/google'
        .query
          code: 'this_is_a_code'
          clientId: 'this_is_a_client_id'
          redirectUri: 'this_is_the_uri'
        .end (err, res) ->
          answer =
            err: err
            res: res
          done()

      it 'should call google twice and return profile', ->
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
        app.models.Account.count email: 'user@example.com', (err, nb) ->
          expect(err).to.not.exist
          expect(nb).to.eql 1
          done err

      it 'should map the profile in the account', (done) ->
        app.models.Account.findOne
          where:
            email: 'user@example.com'
        , (err, found) ->
          expect(err).to.not.exist
          expect(found).to.exist
          expect(found.google).to.eql profile.sub
          expect(found.firstName).to.eql profile.given_name
          expect(found.lastName).to.eql profile.family_name
          expect(found.gender).to.eql profile.gender
          done err

