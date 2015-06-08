var satellizer = require('../../../lib/index.js');

module.exports = function enableAuthentication(server) {
  // enable authentication
  server.enableAuth();
  // enable facebook
  satellizer.Facebook({
    model: server.models.Account,
    facebook: {
      credentials: server.settings.provider.facebook,
      uri: '/facebook',
      mapping: {
        id: 'facebook',
        email: 'email',
        first_name: 'firstName',
        last_name: 'lastName',
        gender: 'gender'
      }
    }
  });
  // enable google
  satellizer.Google({
    model: server.models.Account,
    google: {
      credentials: server.settings.provider.google,
      uri: '/google',
      mapping: {
        id: 'google',
        email: 'email',
        first_name: 'firstName',
        last_name: 'lastName',
        gender: 'gender'
      }
    }
  });
  // enable twitter
  satellizer.Twitter({
    model: server.models.Account,
    twitter: {
      credentials: server.settings.provider.twitter,
      uri: '/twitter',
      mapping: {
        id: 'twitter',
        screen_name: 'firstName',
        screen_name: 'lastName'
      }
    }
  });
};
