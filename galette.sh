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

link=

# Default flags
fortify=
ssp=
signed_overflow=
exceptions=
pic=
pie=
lto=
visibility=
auto_init=
combreloc=
relro=
now=
hashstyle=

# Retrieve flags from environment
comp=""
list="$GALETTE_FLAGS"

until [ "$comp" = "$list" ]
do
	comp="${list%% *}"
	list="${list#* }"

	case "${comp#[+-]}" in
	(format-security|cxx-bounds|fortify|stack-clash|ssp|signed-overflow|exceptions|pic|pie|slh|cfi|lto|auto-init|combreloc|relro|now|hashstyle)
		var="${comp#[+-]}"
		var_="${var//-/_}"
		if [ "${comp%${var}}" = "-" ]
		then
			unset $var_
		else
			eval $var_=
		fi;;
	esac
done

# Process command-line arguments
for arg in "$@"
do
	case "$arg" in
	(-c)
		unset link;;
	(-[DU]_GLIBCXX_ASSERTIONS)
		unset cxx_bounds;;
	(-[DU]_FORTIFY_SOURCE|-D_FORTIFY_SOURCE=*)
		unset fortify;;
	(-pthread|-lpthread)
		pthread=;;
	(-fstrict-overflow|-fno-strict-overflow|-fwrapv|-fno-wrapv|-fwrapv-pointer|-fno-wrapv-pointer)
		unset signed_overflow;;
	(-fexceptions|-fno-exceptions)
		unset exceptions;;
	(-fstack-protector|-fstack-protector-*|-fno-stack-protector|-fno-stack-protector-*)
		unset ssp;;
	(-fPI[CE]|-fpi[ce]|-fno-PIC|-fno-pic|-static|-Bstatic|-Wl,-pie|-pie)
		unset pic pie;;
	(-fno-PIE|-fno-pie|-shared|-Bshareable|-nopie)
		unset pie;;
	(-mspeculative-load-hardening|-mno-speculative-load-hardening)
		unset slh;;
	(-ffreestanding|-fno-hosted|-nodefaultlibs|-nostdlib)
		unset fortify ssp;;
	(-flto|-flto=*|-fno-lto)
		unset lto;;
	(-fsanitize=cfi|-fsanitize=cfi-*|-fno-sanitize=cfi|-fno-sanitize=cfi-*)
		unset cfi;;
	(-fvisibility=*)
		unset visibility;;
	(-ftrivial-auto-var-init=*)
		unset auto_init;;
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

# No thread cancellation hardening for single-threaded programmes
[ -n "${pthread+x}" ] && unset exceptions

# No PIC if PIE
[ -n "${pie+x}" ] && unset pic

# CFI requires LTO and explicit visibility
[ -z "${lto+x}" ] && unset cfi
[ -z "${cfi+x}" ] && unset visibility

# Launch the compiler binary
exec -a "$bin" "$binp" \
	${format_security+-Wformat -Werror=format-security} \
	${cxx_bounds+-D_GLIBCXX_ASSERTIONS} \
	${fortify+-D_FORTIFY_SOURCE=2 -O} \
	${stack_clash+-fstack-clash-protection} \
	${ssp+-fstack-protector-strong} \
	${signed_overflow+-fno-strict-overflow} \
	${exceptions+-fexceptions} \
	${pic+-fPIC} \
	${pie+-fPIE} \
	${slh+-mspeculative-load-hardening} \
	${lto+-flto=thin} \
	${cfi+-fsanitize=cfi} \
	${visibility+-fvisibility=default} \
	${auto_init+-ftrivial-auto-var-init=zero -enable-trivial-auto-var-init-zero-knowing-it-will-be-removed-from-clang} \
	${link+ \
		${pie+-pie} \
		${combreloc+-Wl,-z,combreloc} \
		${relro+-Wl,-z,relro} \
		${now+-Wl,-z,now} \
		${hashstyle+-Wl,--hash-style=gnu}} \
	"$@"
