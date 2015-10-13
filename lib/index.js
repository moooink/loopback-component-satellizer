'use strict';
module.exports = function(app, config) {
  var facebook, google, twitter;
  console.log(config);
  if (config.facebook) {
    facebook = require('./facebook');
    facebook(app, config.facebook);
  }
  if (config.google) {
    google = require('./google');
    google(app, config.google);
  }
  if (config.twitter) {
    twitter = require('./twitter');
    return twitter(app, config.twitter);
  }
};
