var async, common, debug, qs, randomstring, request;

async = require('async');

debug = require('debug')('loopback:satellizer:twitter');

qs = require('querystring');

request = require('request');

randomstring = require('randomstring');

common = require('../common');

module.exports = function(options) {
  var Common, Model, callbackUrl, credentials, fetchAccessToken, fetchProfile, handleFirstRequest, link;
  Common = common(options);
  Model = options.model;
  credentials = options.twitter.credentials;
  callbackUrl = options.twitter.callbackUrl;
  handleFirstRequest = function(callback) {
    return request.post({
      url: 'https://api.twitter.com/oauth/request_token',
      oauth: {
        consumer_key: credentials["public"],
        consumer_secret: credentials["private"]
      }
    }, function(err, res, body) {
      if (err) {
        return callback(err);
      }
      return callback(null, qs.parse(body));
    });
  };
  fetchAccessToken = function(oauthToken, oauthVerifier, callback) {
    return request.post({
      url: 'https://api.twitter.com/oauth/access_token',
      oauth: {
        consumer_key: credentials["public"],
        consumer_secret: credentials["private"],
        token: oauthToken,
        verifier: oauthVerifier
      }
    }, function(err, res, accessToken) {
      if (err) {
        return callback(err);
      }
      return callback(null, qs.parse(accessToken));
    });
  };
  fetchProfile = function(accessToken, callback) {
    debug('fetchProfile');
    return request.get({
      url: 'https://api.twitter.com/1.1/users/show.json?screen_name=' + accessToken.screen_name,
      oauth: {
        consumer_key: credentials["public"],
        consumer_secret: credentials["private"],
        oauth_token: accessToken.oauth_token
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
      query.where[options.twitter.mapping.id] = profile.id;
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
      email: profile.id + "@twitter.com",
      password: randomstring.generate()
    };
    Common.map(options.twitter.mapping, profile, tmp);
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
    if (account[options.twitter.mapping.id] && account[options.twitter.mapping.id] !== profile.id) {
      err = new Error('account_conflict');
      err.status = 409;
      debug(err);
      return callback(err);
    }
    Common.map(options.twitter.mapping, profile, account);
    return account.save(function(err) {
      if (err) {
        debug(err);
      }
      return callback(err, account);
    });
  };
  Model.twitter = function(req, oauthToken, oauthVerifier, callback) {
    debug(oauthToken + ", " + oauthVerifier);
    if (!oauthToken || !oauthVerifier) {
      return handleFirstRequest(callback);
    }
    return async.waterfall([
      function(done) {
        return fetchAccessToken(oauthToken, oauthVerifier, done);
      }, function(accessToken, done) {
        return fetchProfile(accessToken, done);
      }, function(profile, done) {
        return link(req, profile, done);
      }, function(account, done) {
        return Common.authenticate(account, done);
      }
    ], callback);
  };
  Model.remoteMethod('twitter', {
    accepts: [
      {
        arg: 'req',
        type: 'object',
        http: {
          source: 'req'
        }
      }, {
        arg: 'oauth_token',
        type: 'string',
        http: {
          source: 'form'
        }
      }, {
        arg: 'oauth_verifier',
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
      path: options.twitter.uri
    }
  });
};
