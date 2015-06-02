expect    = require('chai').expect
loopback  = require 'loopback'

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
