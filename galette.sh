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

# Enable flags
fortify=1
ssp=1
pic=1
pie=1
combreloc=1
relro=1
now=1

# Process command-line arguments
for arg in "$@"
do
	case "$arg" in
	(-c)
		unset combreloc relro now;;
	(-fstack-protector|-fstack-protector-all|-fno-stack-protector|-fno-stack-protector-all)
		unset ssp;;
	(-D_FORTIFY_SOURCE|-D_FORTIFY_SOURCE=*|-U_FORTIFY_SOURCE)
		unset fortify;;
	(-fPIC|-fpic|-fPIE|-fpie|-fno-PIC|-fno-pic|-static|-i|-r|-pie)
		unset pic pie;;
	(-fno-PIE|-fno-pie|-shared|-nopie)
		unset pie;;
	(-Wl,-z,combreloc|-Wl,-z,nocombreloc)
		unset comreloc;;
	(-Wl,-z,relro|-Wl,-z,norelro)
		unset relro;;
	(-Wl,-z,lazy|-Wl,-z,now)
		unset now;;
	(--)
		break;;
	esac
done

# No PIC if PIE
[ $pie ] && unset pic

# Launch the compiler binary
exec "$bin" \
	${ssp:+-fstack-protector-all} \
	${fortify:+-D_FORTIFY_SOURCE=2 -O} \
	${pic:+-fPIC} \
	${pie:+-fPIE -pie} \
	${combreloc:+-Wl,-z,combreloc} \
	${relro:+-Wl,-z,relro} \
	${now:+-Wl,-z,now} \
	"$@"
