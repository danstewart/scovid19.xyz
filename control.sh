#!/usr/bin/env bash

# Defaults
env='dev'

# Arg parse
while [[ "$#" -gt 0 ]]; do
	case "$1" in
		--env) env=$2; shift ;;
		--docker) docker=$2; shift ;;
		--flask) flask=$2; shift ;;
		--in-container) in_container=1; shift ;;
		-h|--help) help=1 ;;
		-f|--force) force=1 ;;
		--) shift; break ;;
	esac

	shift
done

# Show help on bad usage
if [[ -z $flask && -z $docker ]]; then
	echo 'Requires one of --flask or --docker'
	echo
fi

if [[ $help ]]; then
	cat << EOF
./control.sh --env <dev|prod> [--flask cmd] [--docker cmd] [--in-container]

Used for running the scovid19.xyz web app.
Should be ran from the app root.

env should be either 'dev' or 'prod' (defaults to dev).

in-container should be passed from docker as an indicator not to load .env

Flask
	up: Starts the flask server

Docker
	up:      Builds and starts a container, pass -f to force rebuild
	down:    Stop a container
	restart: Restart a container
	deploy:  Stops and recreates the container
EOF

	exit 0
fi

# Load .env, if we're not within a container
# Docker should handle all env from the .env at creation
if [[ -z $in_container && -f .env ]]; then
	set -o allexport
	source .env
	set +o allexport
fi

# Check our root is set for flask
if [[ -n $flask && -z $SCOVID_PROJECT_ROOT ]]; then
	if [[ -d scovid19 && -f scovid19/__init__.py ]]; then
		export SCOVID_PROJECT_ROOT=$(pwd)
	else
		echo "SCOVID_PROJECT_ROOT is not set, add this to secrets.bash or run me like: SCOVID_PROJECT_ROOT=$(pwd) $0"
		exit 1
	fi
fi

# If using flask then we need to be in the proj root
if [[ -n $flask &&  $(realpath $(pwd)) != $(realpath $SCOVID_PROJECT_ROOT) ]]; then
	echo "This script needs to be ran from the app root ($SCOVID_PROJECT_ROOT)"
	echo "You are in $(pwd)"
	exit 1
fi

# Dev using flask
if [[ $flask == 'up' ]]; then
	# Set up virtual env if not already done
	if [[ ! -d venv ]]; then
		python -m venv venv
		source venv/bin/activate
		pip install -r requirements.txt
	fi

	export SCOVID_ENV=$env
	if [[ $env == 'dev' ]]; then
		source venv/bin/activate
		FLASK_APP=scovid19 FLASK_ENV=development FLASK_DEBUG=True flask run --host 0.0.0.0

	elif [[ $env == 'prod' ]]; then
		source venv/bin/activate
		gunicorn \
			--workers 4 \
			--threads 4 \
			--bind 0.0.0.0:5000 \
			--worker-tmp-dir /dev/shm \
			--log-file ./logs/app.log \
			--error-logfile ./logs/app.log \
			--log-level debug \
			--capture-output \
			scovid19:app

	else
		echo "Invalid env value '$env'"
	fi

	exit 0
fi

# Docker
if [[ -n $docker ]]; then
	name='scovid'
	running=$(docker ps -q -f name=$name)

	# Set which app we're starting
	[[ $env == 'dev' ]] && app_name='app-dev' || app_name='app'

	# If not running and trying to deploy, then just start
	[[ -z $running && $docker == 'deploy' ]] && docker='up'

	# If running in dev mode then only run on one port
	# In production we need two ports to deploy without downtime
	[[ $env == 'dev' ]] && export PORTS=5000

	# Build and run
	if [[ $docker == 'up' ]]; then
		if [[ $running && -z $force ]]; then
			echo "$name container is already running, pass --force to rebuild"
			exit 1
		fi
		
		# If running with --force then always rebuild
		extra=""
		if [[ -n $force ]]; then
			extra=" --build --no-deps"
		fi

		export SCOVID_ENV=$env
		docker-compose up -d $extra $app_name
		echo "Built and started $name"

	# Stop
	elif [[ $docker == 'down' ]]; then
		docker-compose down
		echo "Container $name brought down"

	# Restart
	elif [[ $docker == 'restart' ]]; then
		docker-compose stop $app_name
		docker-compose start $app_name
		echo "Container $name restarted"

	elif [[ $docker == 'deploy' ]]; then
		if [[ $env == 'dev' ]]; then
			echo "Cannot deploy while in dev mode, pass `--env prod`"
			exit 1
		fi

		# Scale up to 2 containers, the new one being our new build
		# Kill the old container, then scale down to 1
		echo "Scaling up $name (NOTE: You can ignore the following two warnings about the container name and port)"
		docker rename $name "${name}_old"
		sleep 2
		docker-compose up -d --scale app=2 --no-recreate --build --no-deps $app_name

		echo "Building new container"
		sleep 20

		echo "New container built, removing old one"
		docker rm -f "${name}_old"
		docker-compose up -d --scale app=1 --no-recreate $app_name
		echo "Deploy finished"

	else
		echo "Invalid docker subcommand '$docker'"
	fi

	exit 0
fi
