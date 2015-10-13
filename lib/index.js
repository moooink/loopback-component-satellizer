'use strict';
module.exports = function(app, config) {
  if (config.facebook) {
    require('./facebook')(app, config.facebook);
  }
  if (config.google) {
    require('./google')(app, config.google);
  }
  if (config.twitter) {
    return require('./twitter')(app, config.twitter);
  }
};
