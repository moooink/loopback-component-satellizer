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
  credentials = options.google.credentials;
  fetchAccessToken = function(code, clientId, redirectUri, callback) {
    debug('fetchAccessToken');
    return request.post({
      url: 'https://accounts.google.com/o/oauth2/token',
      form: {
        code: code,
        client_id: clientId,
        client_secret: credentials["private"],
        redirect_uri: redirectUri,
        grant_type: 'authorization_code'
      },
      json: true
    }, function(err, res, token) {
      if (err) {
        return callback(err);
      }
      return callback(null, token.access_token);
    });
  };
  fetchProfile = function(accessToken, callback) {
    debug('fetchProfile');
    return request.post({
      url: 'https://www.googleapis.com/plus/v1/people/me/openIdConnect',
      headers: {
        Authorization: "Bearer: " + accessToken
      },
      json: true
    }, function(err, res, profile) {
      if (err) {
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
        where: {}
      };
      query.where[options.google.mapping.id] = profile.email;
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
    var tmp;
    debug('link.create', profile.id);
    tmp = {
      password: randomstring.generate()
    };
    Common.map(options.google.mapping, profile, tmp);
    return Model.create(tmp, function(err, created) {
      if (err) {
        debug(err);
      }
      return callback(err, created);
    });
  };
  link.existing = function(profile, account, callback) {
    var err;
    debug('link.existing');
    if (account.google && account[options.google.mapping.id] !== profile.id) {
      err = new Error('account_conflict');
      err.status = 409;
      debug(err);
      return callback(err);
    }
    Common.map(options.google.mapping, profile, account);
    return account.save(function(err) {
      if (err) {
        debug(err);
      }
      return callback(err, account);
    });
  };
  Model.google = function(req, code, clientId, redirectUri, callback) {
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
  Model.remoteMethod('google', {
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
      path: options.google.uri
    }
  });
};
