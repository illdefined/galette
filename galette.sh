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
warn=1
fortify=1
lto=1
ssp=1
wrap=1
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
	(-[DU]_FORTIFY_SOURCE|-D_FORTIFY_SOURCE=*)
		unset fortify;;
	(-flto|-flto=*|-fno-lto)
		unset lto;;
	(-fstack-protector|-fstack-protector-*|-fno-stack-protector|-fno-stack-protector-*)
		unset ssp;;
	(-f[tw]rapv|-fno-[tw]rapv)
		unset wrap;;
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
[ -n "${pie+x}" ] && unset pic

# Launch the compiler binary
exec "$bin" \
	${warn+ \
		-Wformat \
		-Wformat-security \
		-Werror=nonnull \
		-Werror=init-self \
		-Werror=sequence-point \
		-Werror=uninitialized \
		-Wstrict-overflow=4 \
		-Werror=array-bounds \
		-Wfloat-equal \
		-Wshadow \
		-Wtype-limits \
		-Wcast-align \
		-Wwrite-strings \
		-Wconversion \
		-Wsign-compare \
		-Wsizeof-pointer-memaccess \
		-Waddress \
		-Wredundant-decls \
		-Wvolatile-register-var \
		-Wpointer-sign \
		-Wstack-protector \
		${gcc+ \
			-Wmaybe-uninitialized \
			-Wtrampolines \
			-Wstack-usage=64 \
			-Wclobbered \
			-Werror=jump-misses-init \
			-Wlogical-op}} \
	${fortify+ \
		-D_FORTIFY_SOURCE=2 -O} \
	${lto+ \
		${gcc+ \
			-flto -ffat-lto-objects}} \
	${ssp+ \
		-fstack-protector-strong} \
	${wrap+ \
		-ftrapv} \
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
			-Wl,-z,now}} \
	"$@"
