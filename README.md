# Checkpoint

Checkpoint is a centralized authentication broker for web applications that supports a number of authentication mechanisms via an http interface. Checkpoint can take care of logging your users into your application and keep track of session and access privileges across services.

[![Build Status](https://semaphoreapp.com/api/v1/projects/4e82122fc31c2c679be6aaded3ebc29929c12dcc/27033/badge.png)](https://semaphoreapp.com/projects/1534/branches/27033)

## Concepts

* *Realm* - The security context for your application. A given session is valid for a specific realm. Realms may span any number of services, but they should ideally be construed as a single coherent 'brand' in the mind of your users. An example realm could be "google" where all the services provided within the 'google' realm shared identities across services.
* *Domain* - A realm is connected to a number of domains (e.g. 'google' realm could be attached to the domains 'maps.google.com' and 'reader.google.com' and even 'youtube.com'). Checkpoint looks at the current host domain to determine the current realm when e.g. logging a user in.
* *Identity* - Represents one specific person. An identity may have a number of accounts.
* *Account* - A verified account with a specific provider that can be used to log in to a specific identity.
* *Provider* - An actual authenication service, e.g. Twitter or Facebook. A provider may offer several authentication strategies.
* *Strategy* - An authentication mechanism, e.g. omniauth. Different providers can offer authentication by the same strategy. See below for implementing custom strategies.


## Basic config

To initiate authentication, you first need to have a realm with a domain set up for your application:

    $ bundle exec ./bin/checkpoint realm create example -t "Example Security Realm" -d example.org

Checkpoint is provided as an http service and needs to be mapped into the url-space of your application using some proxy mechanism. The standard root url for checkpoint is:

    /api/checkpoint/v1/

In production this mapping is done with ha-proxy. In development a rack proxy will be provided.

## Typical usage

Given that your basic config is set up, your user can log in by being sent to the appropriate login action. A "Log in with Twitter" link should direct the browser to the following url:

    /api/checkpoint/v1/login/twitter

An authentication process will commence possibly taking your user via twitter to confirm their identity. If login is successful your user is returned to your application at:

    /login/succeeded

The session key for the logged in user is now stored in the cookie named 'checkpoint.session'. This is a 512 bit hash that can be used with all Pebble-compliant web-services to identify your current user and her credentials. (Unsuccessful logins are returned to: /login/failed)

Currently Checkpoint supports the following authentication mechanisms:

* Twitter
* Facebook
* Google
* Origo

## Sessions

The basic purpose of Checkpoint is providing and managing sessions for your users. A session in Checkpoint is represented by a 512 bit string of random garbage, the 'session string'. This string can be passed around to all pebbles compliant web services as proof of identity.

To check the identity for a specific session, this call to checkpoint could be used:

    /api/checkpoint/v1/identity/me?session=10e9pde6ww4kr5nv7y9k54kei1dj1lfe9s [...]

Pebbles expect to find the session string in one of two places. First it looks for a url-parameter named 'session', if it is not found there it will attempt to retrieve it from a cookie named 'checkpoint.session'. If neither of these are present the request will be processed without authentication.

## Fingerprinting

For each account registered with an identity, one or more *fingerprints* are recorded for posterity based on the account information. The fingerprint is an SHA-256 hash computed from the immutable parts of the account information, such as one's Twitter UID, mobile number or similar.

The fingerprint obscures the original details but still permits the application to determine if a future credential has been fingerprinted, thus making it possible to ban Twitter users, mobile numbers, etc. without having the original information at hand.

Checkpoint exposes an API that can be used to check for banned fingerprints. This API uses the Pebblebed path system, so that the banning system can be used not only for blocking logins, but for fine-grained access control such as blocking users from posting in a forum.

## Callbacks

Pebbles have default rules guarding who gets to do what to a given object. Callbacks allow implementation of custom policies for creating, updating and deleting objects.

A callback is registered with a path and an url. If a callback is registered with the path 'a.b.c' it will be consulted for any action within that path, i.e. it will be called when someone wants to update `post:a.b.c.d.e.f.g$11` or `post:a.b.c$1`, but not `post:a$1`or `post:z.y.x$666`.

When a pebble consults checkpoint to determine if an action should be allowed, the callback will post to the url. The post will recieve the parameters `method`, `uid` and `identity`. `method` will be either 'create', 'update' or 'delete', `uid` is the uid of the object the action will be taken on, `identity` is the id of the identity attempting to perform the action. The callback should return a json-hash with the key `allowed`. If the action should be allowed, `allowed` should be true, if it should be denied: false. If the callback does not have a specific opinion on the matter it should respond with an empty hash. If the callback chooses to deny the action, it should provide a `reason` in the response hash. This is a human readable string that may be presented to a user.

At the time of writing, only Grove actually consults checkpoint callbacks. In the future all pebbles must support this. To support callbacks, a pebble must GET `/callbacks/allowed/:method/:uid` before performing the action. The `allowed` key in the response will be either `true`, `false` or `default`. `true` means 'categorically allowed, override default behavior', `false` means 'categorically' denied, while `default` means 'apply internal rules, the callbacks had nothing to say about this'. Typically this means no callback was defined for the path in question. If the action has been denied, the response will also include the `url` of the denying callback along with a textual `reason` for the denial.

## Tagging

Identities support arbitrary sets of tags. (A tag can be any string, including spaces.) The main use case is to allow apps to tag the origin of identities when there may be multiple applications sharing the same realm.

For example, if you develop apps A and B, and these apps tag their identities accordingly, then it's trivial to determine which identities came from which app. If, say, app B is discontinued or must be moved to a separate realm, it's easy to purge/move the identities if they have been tagged correctly.

Tagging is entirely-freeform and can serve any purpose, however.


## Custom strategy and provider

A customized installation of Checkpoint might need to implement its own provider and strategy for authentication against an existing user/password store. Refer to `config/strategies-example.rb` and the [checkpoint-strategy](https://github.com/bengler/checkpoint-strategy) gem to set up a Checkpoint compliant provider and strategy.


## Known weaknesses

* The service defines a critical single point of failure. Infrastructure should be put in place for a redundant solution – either a high-availability memcached cluster or a different key-value store.

## Installation

### Get the code

    $ git clone git://github.com/bengler/checkpoint.git

### Configure ActiveRecord

    $ cp config/database-example.yml config/database.yml
    $ $EDITOR config/database.yml

### Bootstrap

    $ ./bin/bootstrap


The bootstrap script will check for dependencies and set up a development environment if PostgreSQL and Memcached are installed.

### Testing

    $ bundle exec rake db:test:prepare
    $ bundle exec rspec spec

### A note on configuring the Evernote strategy for sandbox use

When developing evernote-apps you will typically start with a sandbox account. To make the auth-mechanism
use your sandbox-account, add a site-key to the evernote service-keys, like this:

    evernote:
      consumer_key: <key>
      consumer_secret: <secret>
      site: 'https://sandbox.evernote.com'
