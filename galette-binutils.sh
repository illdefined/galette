#!/bin/sh

set -e

self="${0##*/}"

if [ "$self" = "galette-binutils" ]
then
	bin="$1"
	shift 1
else
	bin="$self"
fi

# Determine canonical binary path
selfp="$(readlink -f "$0")"

# Search for linker binary in PATH
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
	# No linker binary found
	exit 127
fi

plugin="$(llvm-config --libdir)/LLVMgold.so"

case "$bin" in
(ar|-*ar-*|*-ar|ar-*)
	cmd="$1"
	shift 1
	exec -a "$bin" "$binp" "$cmd" --plugin "$plugin" "$@";;
(ranlib|-*ranlib-*|*-ranlib|ranlib-*)
	exit 0;;
(*)
	exec -a "$bin" "$binp" --plugin "$plugin" "$@";;
esac


