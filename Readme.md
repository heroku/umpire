# Umpire

## Overview

Umpire provides a normalized HTTP endpoint that responds with 200 / non-200 according to the metric check parameters specified in the requested URL. This endpoint can then be composed with existing HTTP-URL-monitoring tools like [Pingdom](http://www.pingdom.com) to enable self-service QoS monitor of metrics.


## Usage Examples

To respond with 200 iff the `pulse.nginx-requests-per-second` metric has had an average value of less than 6000 over the last 300 seconds:

```bash
$ curl -i "$UMPIRE_URL/check?metric=pulse.nginx-requests-per-second&max=6000&range=300"
```

To respond with 200 iff the `custom.api.production.requests.per-sec` metric has had an average value of more than 40 over the past 60 seconds:

```bash
$ curl -i "$UMPIRE_URL/check?metric=custom.api.production.requests.per-sec&min=40&range=60"
```


## Local Deploy

```bash
$ rvm use 1.9.2
$ bundle install
$ export DEPLOY=dev
$ export FORCE_HTTPS=false
$ export API_KEY=secret
$ export GRAPHITE_URL=https://graphite.you.com
$ foreman start
$ curl -i "http://umpire:secret@127.0.0.1:5000/check?metric=pulse.nginx-requests-per-second&max=6000&range=300"
```


## Platform Deploy

```bash
$ export DEPLOY=production/staging/you
$ export API_KEY=$(openssl rand -hex 16)
$ heroku create -s cedar -r $DEPLOY umpire-$DEPLOY
$ heroku config:add -r $DEPLOY DEPLOY=$DEPLOY
$ heroku config:add -r $DEPLOY FORCE_HTTPS=true
$ heroku config:add -r $DEPLOY API_KEY=$API_KEY
$ heroku config:add -r $DEPLOY GRAPHTIE_URL=https://you.graphite.com
$ git push $DEPLOY master
$ heroku scale -r $DEPLOY web=3
$ curl -i "https://umpire:$API_KEY@umpire-$DEPLOY.herokuapp.com/check?metric=pulse.nginx-requests-per-second&max=6000&range=300"
```


## Health

Check the health of the Umpire process itself with:

```bash
$ curl -i http://127.0.0.1:5000/health
```
