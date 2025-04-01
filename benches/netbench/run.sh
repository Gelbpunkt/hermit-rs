#!/usr/bin/env bash

# Usage:   run.sh TARGET BIN
# Example: run.sh linux server-bw
#          run.sh hermit client-bw

set -o errexit

netbench_dir="${0%/*}"
root_dir="$netbench_dir"/../..
loader_dir="$root_dir"/../loader

bin=$2
args="--bytes 1048576 --rounds 5000"

hermit() {
    echo "Building loader"

    pushd $loader_dir
    cargo xtask build --target x86_64 --release
    popd

    echo "Building $bin image"

    HERMIT_LOG_LEVEL_FILTER=Trace cargo build --manifest-path "$netbench_dir"/Cargo.toml --bin $bin \
        --release --target x86_64-unknown-hermit

    echo "Launching $bin image on QEMU"

    mkdir -p tracedir
    sudo /usr/libexec/virtiofsd --socket-path=/tmp/vhostqemu --shared-dir=$(pwd)/tracedir --announce-submounts --sandbox none --seccomp none --inode-file-handles=never &
    sleep 1
    sudo chmod 777 /tmp/vhostqemu

    sudo qemu-system-x86_64 -cpu host,migratable=no,+invtsc,enforce \
            -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
            -enable-kvm -display none -smp 1 -m 1G -serial stdio \
            -kernel "$loader_dir"/target/release/hermit-loader-x86_64 \
            -initrd "$root_dir"/target/x86_64-unknown-hermit/release/$bin \
            -netdev user,id=u1,hostfwd=tcp::7878-:7878,hostfwd=udp::7878-:7878,net=192.168.76.0/24,dhcpstart=192.168.76.9 \
            -device virtio-net-pci,netdev=u1,disable-legacy=on,packed=on,mq=on \
            -chardev socket,id=char0,path=/tmp/vhostqemu \
            -device vhost-user-fs-pci,queue-size=1024,packed=on,chardev=char0,tag=tracedir \
            -object memory-backend-file,id=mem,size=1G,mem-path=/dev/shm,share=on \
            -numa node,memdev=mem \
            -append "-- --address 0.0.0.0 $args"

    nm -n "$root_dir"/target/x86_64-unknown-hermit/release/$bin > tracedir/tcp-bw-server.sym
    uftrace dump -d tracedir --flame-graph > tracedir/flamegraph.txt
    flamegraph.pl tracedir/flamegraph.txt > tracedir/flamegraph.svg
    firefox tracedir/flamegraph.svg
}

linux() {
    echo "Launching $bin on linux"

    cargo run --manifest-path "$netbench_dir"/Cargo.toml --bin $bin \
        --release \
        --target x86_64-unknown-linux-gnu \
        -- \
        --address 127.0.0.1 $args
}

$1
