export REPO=https://github.com/ElementsProject/lightning.git
export COMMIT=21afe1c0f403b470f5ef6f117f9e3e58d48b7935
export TOOLCHAIN=aarch64-linux-android-clang
export TARGETHOST=aarch64-linux-android
export BITS=64

bash fetchbuild.sh $REPO $COMMIT $TOOLCHAIN $TARGETHOST $BITS
