#! /bin/bash
set -e
set -o xtrace

repo=$1
commit=$2
target_host=$3
bits=$4
root_dir=$5

export PATH=/opt/android-ndk-r19b/toolchains/llvm/prebuilt/linux-x86_64/bin:${PATH}
export AR=${target_host/v7a/}-ar
export AS=${target_host}21-clang
export CC=${target_host}21-clang
export CXX=${target_host}21-clang++
export LD=${target_host/v7a/}-ld
export STRIP=${target_host/v7a}-strip
export LDFLAGS="-pie -static-libstdc++"
export BUILD=x86_64
export MAKE_HOST=$target_host
export HOST=$target_host

toolchain=${CC}

num_jobs=4
if [ -f /proc/cpuinfo ]; then
    num_jobs=$(grep ^processor /proc/cpuinfo | wc -l)
fi

export NDK_PREFIX=/opt/android-ndk-r19b/${toolchain}/${target_host}

# Copy what's required for compiling raspberry pi build in https://github.com/ElementsProject/lightning/blob/master/doc/INSTALL.md
wget https://zlib.net/zlib-1.2.11.tar.gz
tar xvf zlib-1.2.11.tar.gz
cd zlib-1.2.11
./configure --prefix=${NDK_PREFIX}
make -j $num_jobs
make install
cd ..
rm zlib-1.2.11.tar.gz
rm -rf zlib-1.2.11

wget https://www.sqlite.org/2018/sqlite-autoconf-3260000.tar.gz
tar xzvf sqlite-autoconf-3260000.tar.gz
cd sqlite-autoconf-3260000
./configure --enable-static --disable-readline --disable-threadsafe --disable-load-extension --host=${target_host} --prefix=${NDK_PREFIX} CC=$CC
make -j $num_jobs
make install
cd ..
rm sqlite-autoconf-3260000.tar.gz
rm -rf sqlite-autoconf-3260000

wget https://gmplib.org/download/gmp/gmp-6.1.2.tar.xz
tar xvf gmp-6.1.2.tar.xz 
cd gmp-6.1.2
./configure --disable-assembly --host=${target_host} CC=$CC --prefix=${NDK_PREFIX}
make -j $num_jobs
make install
cd ..
rm gmp-6.1.2.tar.xz 
rm -rf gmp-6.1.2

# Download lightning
git clone $repo lightning
cd lightning
git checkout $commit


# Skip ./configure by hardcoded configs
cp $root_dir/config.vars .
cp $root_dir/config.h ccan/
mkdir external/libbacktrace-build/
cp $root_dir/backtrace-supported.h external/libbacktrace-build
cp $root_dir/gen_header_versions.h .

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
sed -i -e 's~ccan/config.h:~#ccan/config.h:~g' Makefile
sed -i -e 's~./configure --reconfigure~#./configure --reconfigure~g' Makefile
sed -i -e 's/stdin/new_stdin/g' lightningd/plugin.c
sed -i -e 's/stdout/new_stdout/g' lightningd/plugin.c
sed -i '1 i #include <sys/types.h>\n#define F_LOCK LOCK_EX\n#define F_ULOCK LOCK_UN\nextern inline int lockf(int fd, int cmd, off_t ignored_len);\ninline int lockf(int fd, int cmd, off_t ignored_len) {return flock(fd, cmd);}' lightningd/lightningd.c
    
sed -i -e "s/NDK_TOOLCHAIN/$toolchain/g" $CONFIG_HEADER
sed -i -e "s/NDK_TOOLCHAIN/$toolchain/g" $CONFIG_VAR_FILE
sed -i -e "s~NDK_PREFIX~$NDK_PREFIX~g" $CONFIG_VAR_FILE
sed -i -e "s~LDLIBS = -L/usr/local/lib -Wl~LDLIBS = -L$NDK_PREFIX/lib -Wl~g" Makefile

export QEMU_LD_PREFIX=/opt/android-ndk-r19b/${toolchain}/${target_host}

# Build ccan tools for local first
make clean -C ccan/ccan/cdump/tools && make CC=gcc LDFLAGS="" -C ccan/ccan/cdump/tools

# Time to compile Android build !
export CPATH=/opt/android-ndk-r19b/${toolchain}/${target_host}/include
BUILD=x86_64 MAKE_HOST=$target_host \
   make PIE=1 DEVELOPER=0 -j $num_jobs\
   CONFIGURATOR_CC="${toolchain} -static" V=1

make DESTDIR=../out install
echo "Done!"
