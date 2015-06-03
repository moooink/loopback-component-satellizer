var async, common, debug, randomstring, request;

async = require('async');

request = require('request');

randomstring = require('randomstring');

debug = console.log;

common = require('../common');

module.exports = function(options) {
  var Common, Model, credentials, fetchAccessToken, fetchProfile, link;
  Common = common(options);
  Model = options.model;
  credentials = options.facebook.credentials;
  fetchAccessToken = function(code, clientId, redirectUri, callback) {
    var params;
    debug('fetchAccessToken');
    params = {
      url: 'https://graph.facebook.com/v2.3/oauth/access_token',
      qs: {
        code: code,
        client_id: clientId,
        client_secret: credentials["private"],
        redirect_uri: redirectUri
      },
      json: true
    };
    return request.get(params, function(err, res, accessToken) {
      if (err) {
        debug(err);
        return callback(err);
      }
      if (res.statusCode !== 200) {
        err = new Error(accessToken.error.message);
        err.status = 500;
        debug(err);
        return callback(err);
      }
      return callback(null, accessToken);
    });
  };
  fetchProfile = function(accessToken, callback) {
    var params;
    debug('fetchProfile');
    params = {
      url: 'https://graph.facebook.com/v2.3/me',
      qs: accessToken,
      json: true
    };
    return request.get(params, function(err, res, profile) {
      if (err) {
        debug(err);
        return callback(err);
      }
      if (res.statusCode !== 200) {
        err = new Error(profile.error.message);
        err.status = 500;
        debug(err);
        return callback(err);
      }
      return callback(null, profile);
    });
  };
  link = function(req, profile, callback) {
    debug('link');
    return Common.current(req, function(err, found) {
      var query;
      if (err) {
        debug(err);
        return callback(err);
      }
      if (found === null) {
        err = new Error('not_an_account');
        err.status = 409;
        debug(err);
        return callback(err);
      }
      if (found) {
        return link.existing(profile, found, callback);
      }
      query = {
        where: {
          email: profile.email
        }
      };
      return Model.findOne(query, function(err, found) {
        if (err) {
          debug(err);
          return callback(err);
        }
        if (!found) {
          return link.create(profile, callback);
        }
        return link.existing(profile, found, callback);
      });
    });
  };
  link.create = function(profile, callback) {
    debug('link.create', profile.id);
    return Model.create({
      email: profile.email,
      password: randomstring.generate(),
      facebook: profile.id,
      firstName: profile.first_name,
      lastName: profile.last_name,
      birthday: profile.birthday,
      gender: profile.gender
    }, function(err, created) {
      if (err) {
        debug(err);
      }
      return callback(err, created);
    });
  };
  link.existing = function(profile, account, callback) {
    var err;
    debug('link.existing');
    if (account.facebook && account.facebook !== profile.id) {
      err = new Error('account_conflict');
      err.status = 409;
      debug(err);
      return callback(err);
    }
    account.facebook = account.facebook || profile.id;
    account.firstName = account.firstName || profile.first_name;
    account.lastName = account.lastName || profile.last_name;
    account.birthday = account.birthday || profile.birthday;
    account.gender = account.gender || profile.gender;
    return account.save(function(err) {
      if (err) {
        debug(err);
      }
      return callback(err, account);
    });
  };
  Model.facebook = function(req, code, clientId, redirectUri, callback) {
    debug(code + ", " + clientId + ", " + redirectUri);
    return async.waterfall([
      function(done) {
        return fetchAccessToken(code, clientId, redirectUri, done);
      }, function(accessToken, done) {
        return fetchProfile(accessToken, done);
      }, function(profile, done) {
        return link(req, profile, done);
      }, function(account, done) {
        return Common.authenticate(account, done);
      }
    ], callback);
  };
  Model.remoteMethod('facebook', {
    accepts: [
      {
        arg: 'req',
        type: 'object',
        http: {
          source: 'req'
        }
      }, {
        arg: 'code',
        type: 'string',
        http: {
          source: 'form'
        }
      }, {
        arg: 'clientId',
        type: 'string',
        http: {
          source: 'form'
        }
      }, {
        arg: 'redirectUri',
        type: 'string',
        http: {
          source: 'form'
        }
      }
    ],
    returns: {
      arg: 'result',
      type: 'object',
      root: true
    },
    http: {
      verb: 'post',
      path: options.facebook.uri
    }
  });
};
