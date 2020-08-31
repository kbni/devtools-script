# `devtools.sh` Development Host Setup Script

So this repo can be used to rapidly setup some useful development tools on your Ubuntu host. This should probably be an ansible playbook and maybe it will be someday, but for now a bash script seemed like the go.

This repo includes the tools to install the following:

* [MongoDB](https://mongodb.com) with [mongo-express](https://github.com/mongo-express/mongo-express)
* [Redis](https://redis.io/) with [rebrow](https://github.com/marians/rebrow)
* [RabbitMQ](https://www.rabbitmq.com/)
* [Portainer](https://portainer.io/)
* [nginx](https://nginx.com/) to reverse proxy, with SSL

This has only been tested on Ubuntu 18.04 but I suspect it will work with Ubuntu 20.04 also.

# HTTP & HTTPS Setup

Be sure that `env.sh` contains the following environment variable exports:

* `DEVTOOLS_DOMAIN` - the domain we should request an SSL certificate for
* `DEVTOOLS_EMAIL` - the email address used for LetsEncrypt registration

Once that is complete, run `./setup.sh setup nginx` -- this should install and configure nginx for you, as well as generate an SSL certificate. You can re-run this command at any time should you need to change the hostname, or redeploy the configuration from `./nginx/`

*If you're running this in a local Virtual Machine that isn't exposed to the Internet, simply set `DEVTOOLS_DOMAIN` to localhost. No attempt to generate a certificate or configure HTTPS will be made.*

## Reverse Proxy Configuration

You will want to modify `nginx/includes/dev-host.conf` to adjust reverse proxy configuration. By default the following are configured (in addition to those required for Redis/RabbitMQ/MongoDB):

* `/app/1` -> `127.0.0.1:8001`
* `/app/2` -> `127.0.0.2:8002`

## HTTP Authentication

Some tools included do not have strong (or any) authentication systems. So HTTP authentication has been implemented using `auth_basic` in nginx.

* To add bob or update bob's password: `./devtools.sh htpasswd bob`
* To remove bob: `./devtools.sh htpasswd -D bob`

*Keep in mind, `./devtools.sh htpasswd` is realy an alias for `htpasswd $DEVTOOLS_HTPASSWD`*

# Docker Setup

To install Docker for Ubuntu, run: `./devtools.sh setup docker` -- it will run the steps outlined in the official [Docker documentation for Installation on Ubuntu](https://docs.docker.com/engine/install/ubuntu/).

## Portainer Setup

Portainer is installed using docker run. To setup Portainer run `./setup.sh setup portainer` and then visit `http://DEVTOOLS_DOMAIN/portainer/` to setup the admin
password. Note that you will also be prompted for HTTP basic authentication.

## Redis/RabbitMQ/MongoDB

To install these:

1. Populate `.env` with the following environment variables _(keeping in mind .env is not a shell file, do not use quotes, see [Environment Variables in Compose](https://docs.docker.com/compose/environment-variables/))_:
   * `RABBITMQ_ERLANG_COOKIE` a cookie for RabbitMQ to use (use a long string)
   * `MONGO_ADMIN_USERNAME` the desired username for your MongoDB administrator
   * `MONGO_ADMIN_PASSWORD` the desired password for your MongoDB administrator
2. Run `docker-compose -f docker/redis-mongo-rabbit/docker-compose.yml --project-directory . up -d`

_This obviously has nothing to do with `devtools.sh` exactly, this is just a standard Docker Compose file. For more information refer to the [Docker Compose documentation](https://docs.docker.com/compose/)._

# More

To get a hold of me, DM me in Twitter: [@awox_actual](https://twitter.com/awox_actual)

I also have a [website/blog](https://kbni.net.au/) which I rarely update.
