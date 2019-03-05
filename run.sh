export REPO=https://github.com/ElementsProject/lightning.git
export COMMIT=21afe1c0f403b470f5ef6f117f9e3e58d48b7935
export TARGETHOST=armv7a-linux-androideabi
export BITS=32

if [ "$root_dir" == '/repo' ]; then
	docker run -v $PWD:/repo debian:stretch /bin/bash -c "/repo/stretch_deps.sh && /repo/fetchbuild.sh $REPO $COMMIT $TARGETHOST $BITS /repo" &
else
	bash fetchbuild.sh $REPO $COMMIT $TARGETHOST $BITS $PWD
fi
