Build status: [![Build Status](https://travis-ci.org/hihidev/clightning_ndk_build.svg?branch=master)](https://travis-ci.org/hihidev/clightning_ndk_build)

c-lightning android ndk build
Forked from https://github.com/lvaccaro/clightning_ndk

As we are not able to run ndk compiled source in qemu-user, we hard coded all configs so it does not require configurator to run to generate configs.

Compile c-lightning using Android NDK

To run it locally:
1). sudo stretch_deps.sh
2). ./run.sh
