#! /bin/bash
set -e

repo=$1
commit=$2
toolchain=$3
target_host=$4
bits=$5

export PATH=/opt/$toolchain/bin:${PATH}
export AR=$target_host-ar
export AS=$target_host-clang
export CC=$target_host-clang
export CXX=$target_host-clang++
export LD=$target_host-ld
export STRIP=$target_host-strip
export LDFLAGS="-pie -static-libstdc++"
export BUILD=x86_64
export MAKE_HOST=$target_host
export HOST=$target_host

num_jobs=4
if [ -f /proc/cpuinfo ]; then
    num_jobs=$(grep ^processor /proc/cpuinfo | wc -l)
fi

# Copy what's required for compiling raspberry pi build in https://github.com/ElementsProject/lightning/blob/master/doc/INSTALL.md
# wget https://zlib.net/zlib-1.2.11.tar.gz
# tar xvf zlib-1.2.11.tar.gz
# cd zlib-1.2.11
# ./configure --prefix=/opt/${toolchain}/${target_host}
# make -j $num_jobs
# make install
# cd ..
# rm zlib-1.2.11.tar.gz
# rm -rf zlib-1.2.11

# wget https://www.sqlite.org/2018/sqlite-autoconf-3260000.tar.gz
# tar xzvf sqlite-autoconf-3260000.tar.gz
# cd sqlite-autoconf-3260000
# ./configure --enable-static --disable-readline --disable-threadsafe --disable-load-extension --host=${target_host} --prefix=/opt/${toolchain}/${target_host} CC=$CC
# make -j $num_jobs
# make install
# cd ..
# rm sqlite-autoconf-3260000.tar.gz
# rm -rf sqlite-autoconf-3260000

# wget https://gmplib.org/download/gmp/gmp-6.1.2.tar.xz
# tar xvf gmp-6.1.2.tar.xz 
# cd gmp-6.1.2
# ./configure --disable-assembly --host=${target_host} CC=$CC --prefix=/opt/${toolchain}/${target_host}
# make -j $num_jobs
# make install
# cd ..
# rm gmp-6.1.2.tar.xz 
# rm -rf gmp-6.1.2

# Download lightning
git clone $repo lightning
cd lightning
git checkout $commit


# Skip ./configure by hardcoded configs
cp ../config.vars .
cp ../config.h ccan/
mkdir external/libbacktrace-build/
cp ../backtrace-supported.h external/libbacktrace-build
cp ../gen_header_versions.h .

# Change settings
export CONFIGURATOR=ccan/tools/configurator/configurator
export CONFIG_VAR_FILE=config.vars
export CONFIG_HEADER=ccan/config.h

sed -i -e 's/$CC $CWARNFLAGS $CDEBUGFLAGS/gcc $CWARNFLAGS $CDEBUGFLAGS/g' configure

sed -i -e 's/HAVE_VALGRIND_MEMCHECK_H=1/HAVE_VALGRIND_MEMCHECK_H=0/g' $CONFIG_VAR_FILE
sed -i -e 's/#define HAVE_VALGRIND_MEMCHECK_H 1/#define HAVE_VALGRIND_MEMCHECK_H 0/g' $CONFIG_HEADER
sed -i -e 's/HAVE_SYS_TERMIOS_H=1/HAVE_SYS_TERMIOS_H=0/g' $CONFIG_VAR_FILE
sed -i -e 's/#define HAVE_SYS_TERMIOS_H 1/#define HAVE_SYS_TERMIOS_H 0/g' $CONFIG_HEADER
sed -i -e 's/HAVE_QSORT_R_PRIVATE_LAST=1/HAVE_QSORT_R_PRIVATE_LAST=0/g' $CONFIG_VAR_FILE
sed -i -e 's/#define HAVE_QSORT_R_PRIVATE_LAST 1/#define HAVE_QSORT_R_PRIVATE_LAST 0/g' $CONFIG_HEADER
sed -i -e 's/CWARNFLAGS := -W/CWARNFLAGS := #/g' Makefile
sed -i -e 's/-lpthread//g' Makefile
sed -i -e 's/ccan\/ccan\/cdump\/tools\/cdump-enumstr.o \$(CDUMP_OBJS) \$(CCAN_OBJS)/\n\techo hihi/g' Makefile
sed -i -e 's/ALL_PROGRAMS += /#ALL_PROGRAMS += /g' Makefile
sed -i -e 's/gen_header_versions.h:/#gen_header_versions.h:/g' Makefile
sed -i -e 's/@tools\/headerversions \$@/#@tools\/headerversions \$@/g' Makefile
sed -i -e 's/stdin/new_stdin/g' lightningd/plugin.c
sed -i -e 's/stdout/new_stdout/g' lightningd/plugin.c
sed -i '1 i #include <sys/types.h>\n#define F_LOCK LOCK_EX\n#define F_ULOCK LOCK_UN\nextern inline int lockf(int fd, int cmd, off_t ignored_len);\ninline int lockf(int fd, int cmd, off_t ignored_len) {return flock(fd, cmd);}' lightningd/lightningd.c
    
sed -i -e "s/NDK_TOOLCHAIN/$toolchain/g" $CONFIG_HEADER
sed -i -e "s/NDK_TOOLCHAIN/$toolchain/g" $CONFIG_VAR_FILE
sed -i -e "s/NDK_TARGET_HOST/$target_host/g" $CONFIG_VAR_FILE

export QEMU_LD_PREFIX=/opt/${toolchain}/${target_host}

# Build ccan tools for local first
make clean -C ccan/ccan/cdump/tools && make CC=gcc LDFLAGS="" -C ccan/ccan/cdump/tools

# Time to compile Android build !
export CPATH=/opt/${toolchain}/${target_host}/include
BUILD=x86_64 MAKE_HOST=$target_host \
   make PIE=1 DEVELOPER=0 -j $num_jobs\
   CONFIGURATOR_CC="${toolchain} -static"

make DESTDIR=../out install
echo "Done!"
