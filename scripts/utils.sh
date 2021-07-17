#!/bin/bash

export PATH=${HOME}/bin:${PATH}

download_file() {
        local path=$1
        local url=$2

        curl -z $path -o $path -L $url
        if [ $? != 0 ]; then
                echo "failed to download $url"
                exit 1
        fi
}

uninstall_binary() {
        local prog=$1
        sudo rm -f $TARGET_DIR/$prog
}

install_binary() {
        local prog=$1
        local url=$2

        download_file $HOME/bin/$prog $url
        chmod a+x $HOME/bin/$prog
}
