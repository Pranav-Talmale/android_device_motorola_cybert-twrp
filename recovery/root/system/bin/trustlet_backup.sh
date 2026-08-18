#!/system/bin/sh

echo "Trustonic: syncing mcRegistry to tzapp" > /dev/kmsg

mkdir -p /mnt/vendor/tzapp

if [ -d /vendor/app/mcRegistry ]; then
    cp -af /vendor/app/mcRegistry/* /mnt/vendor/tzapp/
    echo "Trustonic: mcRegistry sync complete" > /dev/kmsg
else
    echo "Trustonic: /vendor/app/mcRegistry does not exist" > /dev/kmsg
fi
