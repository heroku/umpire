# Umpire

[![Build Status](https://secure.travis-ci.org/heroku/umpire.png)](http://travis-ci.org/heroku/umpire)

## Overview

Umpire provides a normalized HTTP endpoint that responds with 200 / non-200 according to the metric check parameters specified in the requested URL. This endpoint can then be composed with existing HTTP-URL-monitoring tools like [Pingdom](http://www.pingdom.com) to enable self-service QoS monitoring of metrics.


## Usage Examples

Grab an `UMPIRE_URL` that you can use to query against:

```bash
$ export UMPIRE_URL=https://u:$(heroku config:get API_KEY -a umpire-production)@umpire.yourdomain.com
```

To respond with 200 if the `pulse.nginx-requests-per-second` metric has had an average value of less than 400 over the last 300 seconds:

```bash
$ curl -i "$UMPIRE_URL/check?metric=pulse.nginx-requests-per-second&max=400&range=300"
```

To respond with 200 if the `custom.api.production.requests.per-sec` metric has had an average value of more than 40 over the past 60 seconds:

```bash
$ curl -i "$UMPIRE_URL/check?metric=custom.api.production.requests.per-sec&min=40&range=60"
```

The default metrics target is Graphite.  If you'd like to check [Librato Metrics](http://metrics.librato.com), just add a `backend=librato` query param:

```bash
$ curl -i "$UMPIRE_URL/check?metric=custom.api.production.requests.per-sec&min=40&range=60&backend=librato"
```

## Librato Support

Librato returns multiple values from their API for a given metric. These include: count, min, max, sum, value (aka mean) and a few others. In addition librato allows you to optionally provide a statistical function used to generate an aggregated time series across sources by providing a `group_by` param.

We support both of these options by specifying your librato metrics like so: `metric_name:<from>:<group_by>`

Example fetching the `active-connections` metric, with group_by=sum and pulling values from the "count" field returned in the "all" block
```bash
$ curl -i "$UMPIRE_URL/check?metric=active-connections:count:sum&backend=librato&range=60&min=1"
```

For more info look [here](http://dev.librato.com/v1/get/metrics/:name)

Pass ```emtpy_ok=true``` to have umpire respond with a 200 if the metrics return with no value within a given range.

## Aggregation
The default metric values aggregation method is averaging, but you can change it by adding an 'aggregate' query param. Possible aggregation methods are `avg`, `sum`, `max` and `min`.

Following query responds with 200 if the `custom.api.production.requests.per-sec` metric has had a maximum value of less than 400 over the last minute:

```bash
$ curl -i "$UMPIRE_URL/check?metric=custom.api.production.requests.per-sec&max=400&range=60&aggregate=max"
```

Following query responds with a 200 if the count of `api.prod.addons.plan-changes.errors` metrics has a maximum value of 10 over the last five minutes.

```bash
$ curl -i curl -i "$UMPIRE_URL/check?metric=api.prod.addons.plan-changes.errors:count&aggregate=sum&max=10&range=300&backend=librato&empty_ok=true"
```

## Local Deploy

```bash
$ rvm use 1.9.2
$ bundle install
$ export DEPLOY=dev
$ export APP=umpire-$DEPLOY
$ export FORCE_HTTPS=false
$ export API_KEY=secret
$ export GRAPHITE_URL=https://graphite.yourdomain.com
$ foreman start
$ export UMPIRE_URL=http://umpire:secret@127.0.0.1:5000
$ curl -i "$UMPIRE_URL/check?metric=pulse.nginx-requests-per-second&max=400&range=300"
```

#### Local Docker

```bash
$ docker-compose build
$ docker-compose run --rm web bash
docker$ bundle install --path .
docker$ bundle exec rake
```

## Platform Deploy

```bash
$ export DEPLOY=production/staging/you
$ export APP=umpire-$DEPLOY
$ export API_KEY=$(openssl rand -hex 16)
$ heroku create -s cedar -r $DEPLOY umpire-$DEPLOY
$ heroku config:add -r $DEPLOY DEPLOY=$DEPLOY
$ heroku config:add -r $DEPLOY FORCE_HTTPS=true
$ heroku config:add -r $DEPLOY API_KEY=$API_KEY
$ heroku config:add -r $DEPLOY GRAPHITE_URL=https://graphite.yourdomain.com
$ git push $DEPLOY master
$ heroku scale -r $DEPLOY web=3
$ export UMPIRE_URL=https://umpire:$API_KEY@umpire-$DEPLOY.herokuapp.com
$ curl -i "$UMPIRE_URL/check?metric=pulse.nginx-requests-per-second&max=400&range=300"
```

## Testing

```bash
$ bundle install
$ bundle exec rake
```

## Health

Check the health of the Umpire process itself with:

```bash
$ curl -i "$UMPIRE_URL/health"
```


## License

Copyright (C) 2012 Mark McGranaghan <mark@heroku.com>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

