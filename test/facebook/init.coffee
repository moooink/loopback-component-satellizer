expect  = require('chai').expect

mod     = require '../../source/index.coffee'

describe 'Facebook module', ->

  it 'should exist', ->
    expect(mod.Facebook).to.exist
  
