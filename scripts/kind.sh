#!/bin/bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

. $DIR/utils.sh

install() {
    install_binary kind https://kind.sigs.k8s.io/dl/v0.11.1/kind-linux-amd64
}

start() {
    kind create cluster
}

stop() {
    kind delete cluster
}

delete() {
    kind delete cluster
}

uninstall() {
    uninstall_binary kind
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
        delete)
                delete
                ;;
        *)
                echo "$0 [install|uninstall|start|stop|status]"
                exit 1
                ;;
esac
