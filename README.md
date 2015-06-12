
# loopback-satellizer

[![Join the chat at https://gitter.im/moooink/loopback-component-satellizer](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/moooink/loopback-component-satellizer?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

[![Build Status](https://travis-ci.org/moooink/loopback-component-satellizer.svg?branch=master)](https://travis-ci.org/moooink/loopback-component-satellizer)

[![Stories in Ready](https://badge.waffle.io/moooink/loopback-component-satellizer.png?label=ready&title=Ready)](https://waffle.io/moooink/loopback-component-satellizer)

# How to use it

## Install the component

    npm install --save loopback-component-satellizer

## Configuration for facebook

In your loopback server boot folder, create or reuse the authentication.js (or whatever name you want), load the component

```javascript
var satellizer = require('loopback-component-satellizer');
```

and then configure the facebook connector

```javascript
satellizer.Facebook({
  // The model that extends User model and where you want to bind the facebook connector
  model: server.models.Account,
  facebook: {
    // Put here the credentials used to connect to Facebook.
    // You can follow the example and put it in your config.json
    credentials: {
      public: 'the_client_id',
      private: 'the_client_secret'
    },
    // The uri of the facebook connexion method
    uri: '/facebook',
    // How you want to map the facebook profile on your model
    // The key is the facebook profile key and the value is your model key
    mapping: {
      id: 'facebook',
      email: 'email',
      first_name: 'firstName',
      last_name: 'lastName',
      gender: 'gender'
    }
  }
});
```

Then configure satellizer in the client and take care of the conflicts between the satellizer authorization token and the loopback authorization token.

## Configuration for Google+

In your loopback server boot folder, create or reuse the authentication.js (or whatever name you want), load the component

    var satellizer = require('loopback-component-satellizer');

and then configure the google connector

```javascript
satellizer.Google({
  // The model that extends User model and where you want to bind the google connector
  model: server.models.Account,
  facebook: {
    // Put here the credentials used to connect to Google.
    // You can follow the example and put it in your config.json
    credentials: {
      public: 'the_client_id',
      private: 'the_client_secret'
    },
    // The uri of the google connexion method
    uri: '/google',
    // How you want to map the google profile on your model
    // The key is the google profile key and the value is your model key
    mapping: {
      sub: 'google',
      email: 'email',
      given_name: 'firstName',
      family_name: 'lastName',
      gender: 'gender'
    }
  }
});
```

Then configure satellizer in the client and take care of the conflicts between the satellizer authorization token and the loopback authorization token.
