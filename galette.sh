#!/bin/sh

set -e

self="$(basename "$0")"

if [ "$self" = "galette" ]
then
	bin="$1"
	shift 1
else
	bin="${self#galette-}"
fi

for arg in "$@"
do
	case "$arg" in
	(-fPIC|-fpic|-fPIE|-fpie|-fno-PIC|-fno-pic|-fno-PIE|-fno-pie|-static|-shared|-i|-r|-pie|-nopie)
		exec "$bin" "$@";;
	(--)
		break;;
	esac
done

exec "$bin" -fPIE -pie "$@"
