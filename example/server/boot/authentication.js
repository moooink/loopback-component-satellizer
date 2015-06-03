var satellizer = require('../../../lib/index.js');

module.exports = function enableAuthentication(server) {
  // enable authentication
  server.enableAuth();
  // enable facebook
  satellizer.Facebook({
    model: server.models.Account,
    facebook: {
      credentials: server.settings.provider.facebook,
      uri: '/facebook'
    }
  });
};
