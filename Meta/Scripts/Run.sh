[ -z "$AMPLEOS_QEMU_BIN" ] && AMPLEOS_QEMU_BIN="qemu-system-i386"
[ -z "$AMPLEOS_QEMU_KERNEL" ] && AMPLEOS_QEMU_KERNEL="Sysroot/boot/bzImage"
[ -z "$AMPLEOS_QEMU_RAM" ] && AMPLEOS_QEMU_RAM="128M"
[ -z "$AMPLEOS_QEMU_CPU" ] && AMPLEOS_QEMU_CPU="max"
[ -z "$AMPLEOS_QEMU_SMP" ] && AMPLEOS_QEMU_SMP="$(nproc)"
[ -z "$AMPLEOS_QEMU_IMG" ] && AMPLEOS_QEMU_IMG="QEMU.img"
[ -z "$AMPLEOS_QEMU_ARGS" ] && AMPLEOS_QEMU_ARGS="
    -kernel $AMPLEOS_QEMU_KERNEL
    -m $AMPLEOS_QEMU_RAM
    -cpu $AMPLEOS_QEMU_CPU
    -smp $AMPLEOS_QEMU_SMP
    -drive file=$AMPLEOS_QEMU_IMG,format=raw,index=0,media=disk
    -serial stdio"
[ -z "$AMPLEOS_QEMU_APP_ARGS" ] && AMPLEOS_QEMU_APP_ARGS="
    root=/dev/sda
    init=/bin/SystemService
    console=ttyS0"

[ -e /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ] && AMPLEOS_QEMU_VIRT="-enable-kvm"

"$AMPLEOS_QEMU_BIN" $AMPLEOS_QEMU_ARGS --append "$AMPLEOS_QEMU_APP_ARGS" $AMPLEOS_QEMU_VIRT
