var satellizer = require('../../../lib/index.js');

module.exports = function enableAuthentication(server) {
  // enable authentication
  server.enableAuth();
  // enable facebook
  satellizer.Facebook({
    model: server.models.Account,
    facebook: {
      credentials: {
        public: server.settings.provider.facebook.public,
        private: server.settings.provider.facebook.private
      },
      fields: server.settings.provider.facebook.fields,
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
        sub: 'google',
        email: 'email',
        given_name: 'firstName',
        family_name: 'lastName',
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
