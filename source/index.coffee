'use strict'

module.exports = (app, config) ->
  if config.facebook
    require('./facebook') app, config.facebook
  if config.google
    require('./google') app, config.google
  if config.twitter
    require('./twitter') app, config.twitter
