#!/bin/bash

# fail hard and fast even on pipelines
set -eo pipefail

image=${2:-deis/controller}
name=deis-controller
ports="-p ${PORT:-8000}:8000"
dir=$(dirname "${BASH_SOURCE[0]}")

discover () {

	# test for etcd connectivity
	export ETCD=${ETCD:-127.0.0.1:4001}
	: ${ETCD:?"ETCD environment variable required (e.g. 127.0.0.1:4001)"}
	set +e
	etcdctl -C $ETCD ls >/dev/null 
	if [[ $? != 0 ]]; then
	 echo Failed to connect to etcd at $ETCD, exiting...
	 exit 1
	fi
	set -e

	export CHEF_SERVER_URL=$(etcdctl -C $ETCD get deis/chef/server-url)
	export CHEF_CLIENT_NAME=$(etcdctl -C $ETCD get deis/chef/client-name)
	export CHEF_CLIENT_KEY=$(etcdctl -C $ETCD get deis/chef/client-key)
	export CHEF_VALIDATION_NAME=$(etcdctl -C $ETCD get deis/chef/validation-name)
	export CHEF_VALIDATION_KEY=$(etcdctl -C $ETCD get deis/chef/validation-key)
	export CHEF_NODE_NAME=$(etcdctl -C $ETCD get deis/chef/node-name)

	export DATABASE_HOST=$(etcdctl -C $ETCD get deis/database/host)
	export DATABASE_USER=$(etcdctl -C $ETCD get deis/database/user)
	export DATABASE_PASSWORD=$(etcdctl -C $ETCD get deis/database/password)
	export DATABASE_NAME=$(etcdctl -C $ETCD get deis/database/name)

	export CACHE_HOST=$(etcdctl -C $ETCD get deis/cache/host)
	export CACHE_PASSWORD=$(etcdctl -C $ETCD get deis/cache/password)
	export CACHE_NAME=$(etcdctl -C $ETCD get deis/cache/name)

	export BUILDER_HOST=$(etcdctl -C $ETCD get deis/builder/host)
	export BUILDER_KEY=$(etcdctl -C $ETCD get deis/builder/key)
	
	export DEIS_SECRET_KEY=$(etcdctl -C $ETCD get deis/controller/secret-key)
	export DEIS_CM_MODULE=$(etcdctl -C $ETCD get deis/controller/cm-module)

	# write -e flags for `docker run`
	discovered="-e CHEF_SERVER_URL=$CHEF_SERVER_URL -e CHEF_CLIENT_NAME=$CHEF_CLIENT_NAME -e CHEF_CLIENT_KEY=$CHEF_CLIENT_KEY -e CHEF_VALIDATION_NAME=$CHEF_VALIDATION_NAME -e CHEF_VALIDATION_KEY=$CHEF_VALIDATION_KEY -e CHEF_NODE_NAME=$CHEF_NODE_NAME -e DATABASE_HOST=$DATABASE_HOST -e DATABASE_USER=$DATABASE_USER -e DATABASE_PASSWORD=$DATABASE_PASSWORD -e DATABASE_NAME=$DATABASE_NAME -e CACHE_HOST=$CACHE_HOST -e CACHE_PASSWORD=$CACHE_PASSWORD -e CACHE_NAME=$CACHE_NAME -e BUILDER_HOST=$BUILDER_HOST -e BUILDER_KEY=$BUILDER_KEY -e DEIS_SECRET_KEY=$DEIS_SECRET_KEY -e DEIS_CM_MODULE=$DEIS_CM_MODULE"

}

discover_test () {

	# test for etcd connectivity
	export ETCD=${ETCD:-127.0.0.1:4001}
	: ${ETCD:?"ETCD environment variable required (e.g. 127.0.0.1:4001)"}
	set +e
	etcdctl -C $ETCD ls >/dev/null 
	if [[ $? != 0 ]]; then
	 echo Failed to connect to etcd at $ETCD, exiting...
	 exit 1
	fi
	set -e

	CHEF_SERVER_URL=$(etcdctl -C $ETCD get deis/chef/server-url)
	CHEF_CLIENT_NAME=$(etcdctl -C $ETCD get deis/chef/client-name)
	CHEF_CLIENT_KEY=$(etcdctl -C $ETCD get deis/chef/client-key)
	CHEF_VALIDATION_NAME=$(etcdctl -C $ETCD get deis/chef/validation-name)
	CHEF_VALIDATION_KEY=$(etcdctl -C $ETCD get deis/chef/validation-key)
	CHEF_NODE_NAME=$(etcdctl -C $ETCD get deis/chef/node-name)

	DATABASE_HOST=$(etcdctl -C $ETCD get deis/database/host)
	DATABASE_USER=$(etcdctl -C $ETCD get deis/database/admin-user)
	DATABASE_PASSWORD=$(etcdctl -C $ETCD get deis/database/admin-pass)
	DATABASE_NAME=$(etcdctl -C $ETCD get deis/database/name)

	CACHE_HOST=$(etcdctl -C $ETCD get deis/cache/host)
	CACHE_PASSWORD=$(etcdctl -C $ETCD get deis/cache/password)
	CACHE_NAME=$(etcdctl -C $ETCD get deis/cache/name)

	DEIS_SECRET_KEY=$(etcdctl -C $ETCD get deis/controller/secret-key)
	DEIS_CM_MODULE="cm.mock"

	# write -e flags for `docker run`
	discovered="-e CHEF_SERVER_URL=$CHEF_SERVER_URL -e CHEF_CLIENT_NAME=$CHEF_CLIENT_NAME -e CHEF_CLIENT_KEY=$CHEF_CLIENT_KEY -e CHEF_VALIDATION_NAME=$CHEF_VALIDATION_NAME -e CHEF_VALIDATION_KEY=$CHEF_VALIDATION_KEY -e CHEF_NODE_NAME=$CHEF_NODE_NAME -e DATABASE_HOST=$DATABASE_HOST -e DATABASE_USER=$DATABASE_USER -e DATABASE_PASSWORD=$DATABASE_PASSWORD -e DATABASE_NAME=$DATABASE_NAME -e CACHE_HOST=$CACHE_HOST -e CACHE_PASSWORD=$CACHE_PASSWORD -e CACHE_NAME=$CACHE_NAME -e DEIS_SECRET_KEY=$DEIS_SECRET_KEY -e DEIS_CM_MODULE=$DEIS_CM_MODULE"

}


case $1 in
 build)
  docker build -t $image $dir
  ;;
 test)
  discover_test
  docker run -t -i -rm $discovered $image python -Wall manage.py test --noinput api cm provider web
  ;;
 server)
  discover
  set +e
  docker run -t -name deis-controller $ports $discovered $image
  echo 
  echo $(docker stop deis-controller) stopped
  echo $(docker rm deis-controller) removed  
  ;;
 worker)
  discover
  set +e
  docker run -t -name deis-worker $discovered $image celery worker --app=deis --loglevel=INFO
  echo 
  echo $(docker stop deis-worker) stopped
  echo $(docker rm deis-worker) removed
  ;;
 shell)
  discover
  docker run -t -i -rm $discovered $image /bin/bash
  ;;
 discover)
  discover
  ;;
 syncdb)
  discover
  docker run -t -i -rm $discovered $image ./manage.py syncdb --noinput --migrate
  ;;
 clean)
  set +e
  echo $(docker stop deis-controller) stopped 2>/dev/null
  echo $(docker stop deis-worker) stopped 2>/dev/null
  echo $(docker rm deis-controller) removed 2>/dev/null
  echo $(docker rm deis-worker) removed 2>/dev/null
  docker rmi deis/controller
  exit 0
  ;;
*)
  echo "Usage: $0 {build|test|server|worker|syncdb|shell|clean} [image]"
  exit 1
  ;;
esac

