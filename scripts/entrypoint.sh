#!/bin/sh

chown -R $UID /root/go/pkg/mod
chown -R $UID /root/.cache/go-build

echo `pwd`

echo /gosu $UID env \
    HOME=/root \
    GOROOT=/usr/lib/go-1.14 \
    GOPATH=/root/go \
    PATH=/usr/lib/go-1.14/bin:/root/go/bin:$PATH \
    ${TARGET_ARCH:+CC=${TARGET_ARCH}-linux-gnu-gcc} \
    ${TARGET_GOARCH:+GOARCH=${TARGET_GOARCH}} \
    CGO_ENABLED=1 \
    GOOS=linux $@

/gosu $UID env \
    HOME=/root \
    GOROOT=/usr/lib/go-1.14 \
    GOPATH=/root/go \
    PATH=/usr/lib/go-1.14/bin:/root/go/bin:$PATH \
    ${TARGET_ARCH:+CC=${TARGET_ARCH}-linux-gnu-gcc} \
    ${TARGET_GOARCH:+GOARCH=${TARGET_GOARCH}} \
    CGO_ENABLED=1 \
    GOOS=linux $@
