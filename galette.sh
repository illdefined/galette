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

if [ "$bin" = "$self" ]
then
	exit 1
fi

if [ "${bin%++}" = "clang" ]
then
	clang=1
else
	gcc=1
fi

# Enable flags
link=1
lto=1
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
		unset link;;
	(-flto|-flto=*|-fno-lto)
		unset lto;;
	(-fstack-protector|-fstack-protector-*|-fno-stack-protector|-fno-stack-protector-*)
		unset ssp;;
	(-[DU]_FORTIFY_SOURCE|-D_FORTIFY_SOURCE=*)
		unset fortify;;
	(-fPI[CE]|-fpi[ce]|-fno-PIC|-fno-pic|-static|-Bstatic|-[ir]|-Wl,-pie|-pie|-nostdlib|-nostartfiles|-D__KERNEL__)
		unset pic pie;;
	(-fno-PIE|-fno-pie|-shared|-Bshareable|-nopie)
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
	${lto:+-flto -ffat-lto-objects} \
	${ssp:+-fstack-protector-strong} \
	${fortify:+-D_FORTIFY_SOURCE=2 -O} \
	${pic:+-fPIC} \
	${pie:+-fPIE${clang:+${link:+ -Wl,-pie}}${gcc:+ -pie}} \
	${link:+${combreloc:+-Wl,-z,combreloc}} \
	${link:+${relro:+-Wl,-z,relro}} \
	${link:+${now:+-Wl,-z,now}} \
	"$@"
