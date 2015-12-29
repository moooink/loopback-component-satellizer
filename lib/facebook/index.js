var async, common, debug, randomstring, request;

async = require('async');

debug = require('debug')('loopback:satellizer:facebook');

request = require('request');

randomstring = require('randomstring');

common = require('../common');

module.exports = function(server, options) {
  var Common, Model, fetchAccessToken, fetchProfile, link, version;
  version = options.version ? options.version : 'v2.3';
  Common = common(server, options);
  Model = server.models[options.model];
  fetchAccessToken = function(code, clientId, redirectUri, callback) {
    var params, ref;
    debug('fetchAccessToken');
    params = {
      url: "https://graph.facebook.com/" + version + "/oauth/access_token",
      qs: {
        code: code,
        client_id: clientId,
        client_secret: options.credentials["private"],
        redirect_uri: redirectUri
      },
      json: true
    };
    if (((ref = options.fields) != null ? ref.length : void 0) > 0) {
      params.qs.fields = options.fields.join(',');
    }
    return request.get(params, function(err, res, accessToken) {
      if (err) {
        debug(JSON.stringify(err));
        return callback(err);
      }
      if (res.statusCode !== 200) {
        if (accessToken && accessToken instanceof Object && accessToken.error) {
          accessToken.error.status = 500;
          return callback(accessToken.error);
        }
        err = new Error(JSON.stringify(accessToken));
        err.status = 500;
        debug(JSON.stringify(err));
        return callback(err);
      }
      return callback(null, accessToken);
    });
  };
  fetchProfile = function(accessToken, callback) {
    var params, ref;
    debug('fetchProfile');
    params = {
      url: "https://graph.facebook.com/" + version + "/me",
      qs: accessToken,
      json: true
    };
    if (((ref = options.fields) != null ? ref.length : void 0) > 0) {
      params.qs.fields = options.fields.join(',');
    }
    return request.get(params, function(err, res, profile) {
      if (err) {
        debug(JSON.stringify(err));
        return callback(err);
      }
      if (res.statusCode !== 200) {
        if (profile && profile instanceof Object && profile.error) {
          profile.error.status = 500;
          return callback(profile.error);
        }
        err = new Error(JSON.stringify(profile));
        err.status = 500;
        debug(JSON.stringify(err));
        return callback(err);
      }
      return callback(null, profile);
    });
  };
  link = function(req, profile, callback) {
    debug('link', JSON.stringify(profile));
    return Common.current(req, function(err, found) {
      var query;
      if (err) {
        debug(JSON.stringify(err));
        return callback(err);
      }
      if (found === null) {
        err = new Error('not_an_account');
        err.status = 409;
        debug(JSON.stringify(err));
        return callback(err);
      }
      if (found) {
        return link.existing(profile, found, callback);
      }
      query = {
        where: {}
      };
      query.where[options.mapping.email] = profile.email;
      return Model.findOne(query, function(err, found) {
        if (err) {
          debug(JSON.stringify(err));
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
    debug('link.create', JSON.stringify(profile));
    tmp = {
      password: randomstring.generate()
    };
    Common.map(options.mapping, profile, tmp);
    return Model.create(tmp, function(err, created) {
      if (err) {
        debug(JSON.stringify(err));
      }
      return callback(err, created);
    });
  };
  link.existing = function(profile, account, callback) {
    var err;
    debug('link.existing', JSON.stringify(profile));
    if (account.facebook && account[options.mapping.id] !== profile.id) {
      err = new Error('account_conflict');
      err.status = 409;
      debug(JSON.stringify(err));
      return callback(err);
    }
    Common.map(options.mapping, profile, account);
    return account.save(function(err) {
      if (err) {
        debug(JSON.stringify(err));
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
  Model['facebook-get'] = function(req, code, callback) {
    var clientId, redirectUri;
    debug('facebook-get', code);
    clientId = options.credentials["public"];
    if (options.redirectUri) {
      redirectUri = options.redirectUri;
    } else {
      redirectUri = req.protocol + "://" + (req.get('host')) + req.baseUrl + options.uri;
    }
    return Model.facebook(req, code, clientId, redirectUri, callback);
  };
  Model.remoteMethod('facebook-get', {
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
          source: 'query'
        }
      }
    ],
    returns: {
      arg: 'result',
      type: 'object',
      root: true
    },
    http: {
      verb: 'get',
      path: options.uri
    }
  });
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
      path: options.uri
    }
  });
};
