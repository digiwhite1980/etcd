#!/bin/sh
########################################################################

function log {
	case "${1}" in
		1)
			echo "$(date +%Y-%m-%d' '%H:%M:%S)] | OK      : ${2}"
			;;
		2)
			echo "$(date +%Y-%m-%d' '%H:%M:%S)] | WARN    : ${2}"
			;;
		3)
			echo "$(date +%Y-%m-%d' '%H:%M:%S)] | ERROR   : ${2}"
			exit 1
			;;
		*)
			echo "$(date +%Y-%m-%d' '%H:%M:%S)] | UNKNOWN : ${2}"
			;;
	esac
}

function binCheck {
	for bin in ${@}
	do
		BIN_PATH=$(which ${bin})
		[[ ! -x "${BIN_PATH}" ]] && log 3 "binCheck: ${bin} not found in local PATH"
	done
}

binCheck git

[[ ! -x $(basename ${0}) ]] 	&& log 3 "Please execute $(basename ${0}) from local directory (./run.sh)"
[[ ! -d "init" ]] 				&& log 3 "./init folder not found."
[[ ! -d "./terraform" ]] 		&& git submodule init

cd init
terraform init
terraform plan -state .terraform_state
terraform apply -state .terraform_state
