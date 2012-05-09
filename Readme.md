# Umpire

## Overview

Check metrics.


## Local Deploy

```bash
$ rvm use 1.9.2
$ bundle install
$ export DEPLOY=dev
$ export FORCE_HTTPS=false
$ export API_KEY=secret
$ export GRAPHITE_URL=https://graphite.you.com
$ foreman start
$ curl -i "http://umpire:secret@127.0.0.1:5000/check?metric=pulse.nginx-requests-per-second&max=6000&span=300"
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
$ curl -i "https://umpire:$API_KEY@umpire-$DEPLOY.herokuapp.com/check?metric=pulse.nginx-requests-per-second&max=6000&span=300"
```
