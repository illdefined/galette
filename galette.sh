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

# Read cache
if [ -n "${XDG_RUNTIME_DIR}" ]
then
	cdir="${XDG_RUNTIME_DIR}/galette/cache"
	mkdir -p -m 0700 "$cdir"

	binpc="${binp//%/%25}"
	binpc="$cdir/${binpc////%2f}"

	if [ -f "$binpc" ]
	then
		. "$binpc"
	fi
fi

# Determine compiler and target
if [ -z "$compiler" ]
then
	compiler="$("$binp" -### -E 2>&1 | grep -E '^(clang|gcc) version')"
	compiler="${compiler% version*}"
fi

if [ -z "$target" ]
then
	target="$("$binp" -dumpmachine)"
fi

# Cache results
if [ -n "$binpc" -a ! -f "$binpc" ]
then
	printf "compiler='%s';target='%s'" "${compiler//\'/\'\'}" "${target//\'/\'\'}" >"$binpc"
fi

case "$compiler" in
(clang|gcc)
	eval $compiler=;;
esac

arch="${target%-*-*-*}"

link=

# Default flags
fortify=
instrument=
instrument_undefined=
vla_bound=
array_bounds=
object_size=
stack_clash=
ssp=
pic=
pie=
libgcc=
libubsan=
lto=
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
	(format-security|cxx-bounds|fortify|instrument|instrument-undefined|vla-bound|signed-overflow|array-bounds|object-size|shadow-stack|safe-stack|stack-clash|ssp|pic|pie|lto|fat-lto|combreloc|relro|now|hashstyle)
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
	(-fno-sanitize=all)
		unset instrument;;
	(-fsanitize=undefined|-fno-sanitize=undefined)
		unset instrument_undefined;;
	(-fsanitize=vla-bound|-fno-sanitize=vla-bound)
		unset vla_bound;;
	(-fsanitize=signed-integer-overflow|-fno-sanitize=signed-integer-overflow)
		unset signed_overflow;;
	(-fsanitize=bounds|-fno-sanitize=bounds)
		unset array_bounds;;
	(-fsanitize=object-size|-fno-sanitize=object-size)
		unset object_size;;
	(-fsanitize=shadow-call-stack|-fno-sanitize=shadow-call-stack)
		unset shadow_stack;;
	(-fsanitize=safe-stack|-fno-sanitize=safe-stack)
		unset safe_stack;;
	(-fstack-protector|-fstack-protector-*|-fno-stack-protector|-fno-stack-protector-*)
		unset ssp;;
	(-fPI[CE]|-fpi[ce]|-fno-PIC|-fno-pic|-static|-Bstatic|-Wl,-pie|-pie)
		unset pic pie;;
	(-fno-PIE|-fno-pie|-shared|-Bshareable|-nopie)
		unset pie;;
	(-ffreestanding|-fno-hosted|-nodefaultlibs|-nostdlib)
		unset libgcc libubsan;;
	(-lgcc)
		libgcc=1;;
	(-lubsan)
		libubsan=1;;
	(-flto|-flto=*|-fno-lto)
		unset lto;;
	(-ffat-lto-objects|-fno-fat-lto-objects)
		unset fat_lto;;
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

# Instrumentation dependencies
[ -z "${instrument+x}" ] && unset instrument_undefined shadow_stack safe_stack
[ -z "${instrument_undefined+x}" ] && unset vla_bound signed_overflow object_size

# Stack protection dependencies
[ "$compiler" != "clang" ] && unset shadow_stack safe_stack
[ "$arch" != "x86_64" ] && unset shadow_stack
[ -n "${shadow_stack+x}" ] && unset safe_stack ssp
[ -n "${safe_stack+x}" ] && unset ssp

# Missing support in clang
[ "$compiler" = "clang" ] && unset stack_clash fat_lto

# Determine number of parallel LTO jobs
[ -n "${lto+x}" -a "$compiler" = "gcc" ] && nproc="$(nproc)"

# Launch the compiler binary
exec -a "$bin" "$binp" \
	${format_security+-Wformat -Werror=format-security} \
	${cxx_bounds+-D_GLIBCXX_ASSERTIONS} \
	${fortify+-D_FORTIFY_SOURCE=2 -O} \
	${instrument_undefined+ \
		${clang+-fsanitize-minimal-runtime} \
		${libubsan--fsanitize-undefined-trap-on-error} \
		${vla_bound+-fsanitize=vla-bound -fno-sanitize-recover=vla-bound} \
		${signed_overflow+-fsanitize=signed-integer-overflow -fno-sanitize-recover=signed-integer-overflow} \
		${array_bounds+-fsanitize=bounds -fno-sanitize-recover=bounds} \
		${object_size+-fsanitize=object-size -fno-sanitize-recover=object-size}} \
	${shadow_stack+-fsanitize=shadow-call-stack} \
	${safe_stack+-fsanitize=safe-stack} \
	${stack_clash+-fstack-clash-protection} \
	${ssp+-fstack-protector-strong} \
	${pic+-fPIC} \
	${pie+-fPIE} \
	${lto+-flto"${nproc:+=${nproc}}" \
		${gcc+-fuse-linker-plugin} \
		${fat_lto+-ffat-lto-objects}} \
	${link+ \
		${pie+-pie} \
		${combreloc+-Wl,-z,combreloc} \
		${relro+-Wl,-z,relro} \
		${now+-Wl,-z,now} \
		${hashstyle+-Wl,--hash-style=gnu}} \
	"$@"
