#!/bin/bash

DIR=$(dirname $0)

OS=linux
ARCH=amd64
TARGET_DIR=/opt

ISTIO_VERSION="1.6.13"
ISTIO_URL="https://github.com/istio/istio/releases/download/$ISTIO_VERSION/istio-$ISTIO_VERSION-$OS-$ARCH.tar.gz"
ISTIO_PKG="istio-$ISTIO_VERSION"
ISTIO_OBJECTS="$TARGET_DIR/$ISTIO_PKG/install/kubernetes/helm/istio/templates/crds.yaml"
ISTIO_DEMO="$TARGET_DIR/$ISTIO_PKG/install/kubernetes/istio-demo.yaml"
ISTIO_NS=istio-system
ISTIOCTL=$TARGET_DIR/$ISTIO_PKG/bin/istioctl

uninstall_istio() {
        sudo rm -rf $TARGET_DIR/$ISTIO_PKG
}

install_istio() {
        echo "Installing Istio"
        local tmpdir=$(mktemp -d)
        cd $tmpdir
        curl -L "$ISTIO_URL" | tar xz
        if [ $? != 0 ]; then
                echo "failed to download $url"
                rm -rf $tmpdir
                exit 1
        fi

        sudo cp -R $ISTIO_PKG $TARGET_DIR
        sudo chmod -R 755 $TARGET_DIR
        sudo cp $ISTIOCTL /usr/bin/
        cd -
        rm -rf $tmpdir
        echo "Istio installed"
}

check_istio() {
        which $ISTIOCTL 2>/dev/null
        if [ $? != 0 ]; then
                echo "istioctl is not installed."
                return 1
        fi
}

install() {
        install_istio
}

uninstall() {
        uninstall_istio
}

stop() {
        echo "Stopping Istio"
        check_istio
        kubectl delete -f $ISTIO_OBJECTS
        echo "Istio stopped"
}

start() {
        echo "Starting Istio"
        check_istio || install_istio
        istioctl install --set profile=demo -y
        kubectl label namespace default istio-injection=enabled
        kubectl -n $ISTIO_NS get services
        echo "Istio started"
}

status() {
        echo "Checking Istio status"
        $ISTIOCTL version
        # TODO: istio status - should be filled
}

case "$1" in
        install)
                install
                ;;
        uninstall)
                uninstall
                ;;
        start)
                start
                ;;
        stop)
                stop
                ;;
        status)
                status
                ;;
        *)
                echo "$0 [install|uninstall|start|stop|status]"
                exit 1
                ;;
esac
