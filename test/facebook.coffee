expect    = require('chai').expect
loopback  = require 'loopback'
nock      = require 'nock'

init      = require './init.coffee'


before (done) ->
  loopback.Application.destroyAll done

describe 'Facebook module', ->

  ds      = null
  Account = null

  options =
    model: null
    facebook:
      credentials:
        public: 'public_key'
        private: 'private_key'
      uri: '/facebook'

  beforeEach ->
    ds = loopback.createDataSource
      connector: 'memory'
    options.model = Account = loopback.User.extend 'Account',
      facebook:
        type: 'string'

  it 'should exist', ->
    expect(init.Facebook).to.exist

  it 'should populate model', ->
    init.Facebook options
    expect(Account).to.exist
    expect(Account.facebook).to.exist

  describe 'call to loopback method', ->

    profile =
      id: 'profile_id'
      email: 'user@example.com'
      first_name: 'firstName'
      last_name: 'lastName'
      birthday: new Date()
      gender: 'male'

    it 'should call facebook twice and return profile', (done) ->
      first = nock 'https://graph.facebook.com'
      .get '/v2.3/oauth/access_token'
      .reply 200, 'my_wonderfull_token'
      second = nock 'https://graph.facebook.com'
      .get '/v2.3/me'
      .reply 200, profile
      #
      # TODO call facebook method
      #
      done()
