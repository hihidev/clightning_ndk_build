export REPO=https://github.com/ElementsProject/lightning.git
export COMMIT=4a11bc07f9bc474cbe5eb6f9e45c71075d40fda3
export TARGETHOST=armv7a-linux-androideabi
export BITS=32

if [ "$root_dir" == '/repo' ]; then
	docker run -v $PWD:/repo debian:stretch /bin/bash -c "/repo/stretch_deps.sh && /repo/fetchbuild.sh $REPO $COMMIT $TARGETHOST $BITS /repo" &
else
	bash fetchbuild.sh $REPO $COMMIT $TARGETHOST $BITS $PWD
fi
