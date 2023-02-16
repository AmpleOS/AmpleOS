USE_FUSE2FS=0

if [ "$(id -u)" != 0 ]; then
    if fuse2fs --help 2>&1 |grep fakeroot > /dev/null; then
        USE_FUSE2FS=1
    else
        set +e
        ${SUDO} -- sh -c "\"$0\" $* || exit 42"
        case $? in
            1)
                die "Script needs root to run"
                ;;
            42)
                exit 1
                ;;
            *)
                exit 0
                ;;
        esac
    fi
else
    : "${SUDO_UID:=0}" "${SUDO_GID:=0}"
fi

disk_usage() {
    expr "$(du -sk --apparent-size "$1" | cut -f1)"
}

inode_usage() {
    find "$1" | wc -l
}

INODE_SIZE=1024
INODE_COUNT=$(($(inode_usage "$SOURCE_DIR/Base") + $(inode_usage Sysroot)))
INODE_COUNT=$((INODE_COUNT + 2000))
DISK_SIZE_BYTES=$((($(disk_usage "$SOURCE_DIR/Base") + $(disk_usage Sysroot)) * 1024))
DISK_SIZE_BYTES=$((DISK_SIZE_BYTES + (INODE_COUNT * INODE_SIZE)))
DISK_IMAGE=QEMU.img

if [ -z "$AMPLEOS_DISK_SIZE_BYTES" ]; then
    DISK_SIZE_BYTES=$((DISK_SIZE_BYTES * 2))
    INODE_COUNT=$((INODE_COUNT * 7))
else
    if [ "$DISK_SIZE_BYTES" -gt "$AMPLEOS_DISK_SIZE_BYTES" ]; then
        die "AMPLEOS_DISK_SIZE_BYTES is set to $AMPLEOS_DISK_SIZE_BYTES but required disk size is $DISK_SIZE_BYTES bytes"
    fi
    DISK_SIZE_BYTES="$AMPLEOS_DISK_SIZE_BYTES"
fi

USE_EXISTING=0
if [ -f $DISK_IMAGE ]; then
    USE_EXISTING=1
    echo "Checking existing image"
    result=0
    e2fsck -f -y $DISK_IMAGE || result=$?
    if [ $result -ge 4 ]; then
        rm -f $DISK_IMAGE
        USE_EXISTING=0
        echo "Not using existing image"
    else
        echo "Ok"
    fi
fi

if [ $USE_EXISTING -eq 1 ];  then
    OLD_DISK_SIZE_BYTES=$(wc -c < $DISK_IMAGE)
    if [ "$DISK_SIZE_BYTES" -gt "$OLD_DISK_SIZE_BYTES" ]; then
        echo "Resizing disk image..."
        qemu-img resize -f raw $DISK_IMAGE "$DISK_SIZE_BYTES" || die "Failed to resize disk image"
        if ! "$RESIZE2FS_PATH" $DISK_IMAGE; then
            rm -f $DISK_IMAGE
            USE_EXISTING=0
            echo "Not using existing image"
        fi
        echo "Ok"
    fi
fi

if [ $USE_EXISTING -ne 1 ]; then
    printf "Creating disk image... "
    qemu-img create -q -f raw $DISK_IMAGE "$DISK_SIZE_BYTES" || die "Failed to create disk image"
    chown "$SUDO_UID":"$SUDO_GID" $DISK_IMAGE || die "Failed to adjust permissions on disk image"
    echo "Ok"

    printf "Creating new filesystem... "
    if [ "$(uname -s)" = "OpenBSD" ]; then
        VND=$(vnconfig $DISK_IMAGE)
        (echo "e 0"; echo 83; echo n; echo 0; echo "*"; echo "quit") | fdisk -e "$VND"
        newfs_ext2fs -D $INODE_SIZE -n $INODE_COUNT "/dev/r${VND}i" || die "Failed to create filesystem"
    else
        mkfs.ext4 -q -I "${INODE_SIZE}" -N "${INODE_COUNT}" $DISK_IMAGE || die "Failed to create filesystem"
    fi
    echo "Ok"
fi

printf "Mounting filesystem... "
mkdir -p Mount
use_genext2fs=0
if [ $USE_FUSE2FS -eq 1 ]; then
    mount_cmd="fuse2fs $DISK_IMAGE Mount/ -o fakeroot,rw"
elif [ "$(uname -s)" = "Darwin" ]; then
    mount_cmd="fuse-ext2 $DISK_IMAGE Mount -o rw+,allow_other,uid=501,gid=20"
elif [ "$(uname -s)" = "OpenBSD" ]; then
    VND=$(vnconfig $DISK_IMAGE)
    mount_cmd="mount -t ext2fs "/dev/${VND}i" Mount/"
elif [ "$(uname -s)" = "FreeBSD" ]; then
    MD=$(mdconfig $DISK_IMAGE)
    mount_cmd="fuse-ext2 -o rw+,direct_io "/dev/${MD}" Mount/"
else
    mount_cmd="mount $DISK_IMAGE Mount/"
fi
if ! eval "$mount_cmd"; then
    if command -v genext2fs 1>/dev/null ; then
        echo "Failed to mount but genext2fs exists, use it instead"
        use_genext2fs=1
    else
        die "Failed to mount filesystem and genext2fs is missing"
    fi
else
    echo "Ok"
fi

cleanup() {
    if [ -d Mount ]; then
        if [ $use_genext2fs = 0 ] ; then
            printf "Unmounting filesystem... "
            if [ $USE_FUSE2FS -eq 1 ]; then
                fusermount -u Mount || (sleep 1 && sync && fusermount -u Mount)
            else
                umount Mount || ( sleep 1 && sync && umount Mount )
            fi
            rmdir Mount
        else
            rm -rf Mount
        fi

        if [ "$(uname -s)" = "OpenBSD" ]; then
            vnconfig -u "$VND"
        elif [ "$(uname -s)" = "FreeBSD" ]; then
            mdconfig -d -u "$MD"
        fi
        echo "Ok"
    fi
}
trap cleanup EXIT

"$SOURCE_DIR/Meta/Scripts/SetupRootFileSystem.sh"

if [ $use_genext2fs = 1 ]; then
    genext2fs -B 4096 -b $((DISK_SIZE_BYTES / 4096)) -N $INODE_COUNT -d Mount $DISK_IMAGE || die "Try increasing image size (genext2fs -b)"
    chmod 0666 $DISK_IMAGE
fi
