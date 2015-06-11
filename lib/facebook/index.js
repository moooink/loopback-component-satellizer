var async, common, debug, randomstring, request;

async = require('async');

debug = require('debug')('loopback:satellizer:facebook');

request = require('request');

randomstring = require('randomstring');

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
        err = new Error(accessToken);
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
        err = new Error(profile);
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
        where: {}
      };
      query.where[options.facebook.mapping.email] = profile.email;
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
    Common.map(options.facebook.mapping, profile, tmp);
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
    if (account.facebook && account[options.facebook.mapping.id] !== profile.id) {
      err = new Error('account_conflict');
      err.status = 409;
      debug(err);
      return callback(err);
    }
    Common.map(options.facebook.mapping, profile, account);
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
