# Leech Web

## Overview

Leech provides web-accessible, real-time filtered views of the Heroku event stream. This provides instant visibility into specific aspects of the Heroku infrastructure and its operations. Leech replaces manual log tailing and filtering.

The Leech web component serves the user-facing web page and associated requests. It is complemented by the [Leech drain](https://github.com/heroku/leech-drain) component.


## Local deploy

```bash
$ cp .env.sample .env
$ export $(cat .env)
$ mate .env
$ redis-server
$ rvm use 1.9.2
$ bundle install
$ foreman start
```


## Platform deploy

```bash
$ heroku create leech-web-production --stack cedar
$ heroku addons:add redistogo:medium
$ heroku config:add DEPLOY=production FORCE_HTTPS=true SESSION_SECRET=`openssl rand -hex 16`
$ git push heroku master
$ heroku scale web=2
```
