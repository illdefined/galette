#!/bin/sh

set -e

self="${0##*/}"

if [ "$self" = "galette" ]
then
	bin="$1"
	shift 1
else
	bin="${self#galette-}"
fi

# Determine canonical binary path
selfp="$(readlink -f "$0")"

# Search for compiler binary in PATH
comp=""
list="$PATH"

until [ "$list" = "$comp" ] || [ -n "$binp" ]
do
	# Split search path component off
	comp="${list%%:*}"
	list="${list#*:}"

	if [ -x "$comp/$bin" ]
	then
		binp="$(readlink -f "$comp/$bin")"

		if [ "$binp" = "$selfp" ]
		then
			unset binp
		fi
	fi
done

if [ -z "$binp" ]
then
	# No compiler binary found
	exit 127
fi

if [ "${bin%++}" = "clang" ]
then
	clang=1
else
	gcc=1
fi

# Enable flags
link=1
warn=1
fortify=1
sanitise=1
check=1
ssp=1
pic=1
pie=1
libgcc=1
combreloc=1
relro=1
now=1
hashstyle=1

# Process command-line arguments
for arg in "$@"
do
	case "$arg" in
	(-c)
		unset link;;
	(-Werror)
		unset warn;;
	(-[DU]_FORTIFY_SOURCE|-D_FORTIFY_SOURCE=*)
		unset fortify;;
	(-fsanitize=*|-fsanitize-*|-fno-sanitize=*|-fno-sanitize-*)
		unset sanitise;;
	(-fstack-check|-fstack-check=*)
		unset check;;
	(-fstack-protector|-fstack-protector-*|-fno-stack-protector|-fno-stack-protector-*)
		unset ssp;;
	(-fPI[CE]|-fpi[ce]|-fno-PIC|-fno-pic|-rdynamic|-static|-Bstatic|-[ir]|-Wl,-pie|-pie)
		unset pic pie;;
	(-fno-PIE|-fno-pie|-shared|-Bshareable|-nopie)
		unset pie;;
	(-ffreestanding|-fno-hosted|-nodefaultlibs|-nostdlib)
		unset sanitise libgcc;;
	(-lgcc)
		libgcc=1;;
	(-Wl,-z,combreloc|-Wl,-z,nocombreloc)
		unset combreloc;;
	(-Wl,-z,relro|-Wl,-z,norelro)
		unset relro;;
	(-Wl,-z,lazy|-Wl,-z,now)
		unset now;;
	(-Wl,--hash-style=*)
		unset hashstyle;;
	(--)
		break;;
	esac
done

# No PIC if PIE
[ -n "${pie+x}" ] && unset pic

# Certain functions may require libgcc
[ -z "${libgcc+x}" ] && unset fortify ssp wrap

# Launch the compiler binary
exec "$binp" \
	${warn+ \
		-Wformat \
		-Wformat-security \
		-Werror=format-security \
		-Wuninitialized \
		-Winit-self \
		-Werror=init-self \
		-Wsequence-point \
		-Werror=sequence-point} \
	${fortify+ \
		-D_FORTIFY_SOURCE=2 -O} \
	${sanitise+ \
		-fsanitize=signed-integer-overflow,object-size \
		-fno-sanitize-recover=signed-integer-overflow,object-size} \
	${check+ \
		-fstack-check} \
	${ssp+ \
		-fstack-protector-strong} \
	${pic+ \
		-fPIC} \
	${pie+ \
		-fPIE} \
	${link+ \
		${pie+ \
			-pie} \
		${combreloc+ \
			-Wl,-z,combreloc} \
		${relro+ \
			-Wl,-z,relro} \
		${now+ \
			-Wl,-z,now} \
		${hashstyle+ \
			-Wl,--hash-style=gnu}} \
	"$@"
