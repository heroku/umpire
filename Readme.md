# Leech Web

User-facing web interface for the [Leech drain](https://github.com/heroku/leech-drain).


## Local deploy

    $ cp .env.sample .env
    $ export $(cat .env)
    $ mate .env
    $ redis-server
    $ rvm use 1.9.2
    $ bundle install
    $ foreman start


## Platform deploy

    $ heroku create leech-web-production --stack cedar
    $ heroku addons:add redistogo
    $ heroku config:add ...
    $ git push heroku master
    $ heroku scale web=2
