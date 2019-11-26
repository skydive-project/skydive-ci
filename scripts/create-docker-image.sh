#!/bin/sh

set -v
set -x
set -e

# Arches are the docker arch names
: ${ARCHES:=amd64 ppc64le s390x}
: ${DOCKER_IMAGE:=skydive/skydive}
: ${DOCKER_IMAGE_SNAPSHOT:=skydive/snapshots}
: ${DOCKER_USERNAME:=skydiveproject}
: ${DOCKER_BINARY:=skydive}
: ${DOCKER_BUILD_COMMAND:=}
: ${DOCKERFILE:=contrib/docker/Dockerfile}
: ${REF:=latest}

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
TAG=${REF##*/}
VERSION=${TAG#v}

[ -n "$VERSION" ] && DOCKER_TAG=$VERSION || DOCKER_TAG=latest

# See if a server forms part of DOCKER_IMAGE, e.g. DOCKER_IMAGE=registry.ng.bluemix.net:8080/skydive/skydive
if [ "${DOCKER_IMAGE%/*/*}" != "${DOCKER_IMAGE}" ]; then
    DOCKER_SERVER=${DOCKER_IMAGE%/*/*}
fi

GOPATH_DIR=/root/go
GOMOD_VOL=mod
GOMOD_DIR=/root/go/pkg/mod
GOBUILD_VOL=gobuild-cache
GOBUILD_DIR=/root/.cache/go-build
TOPLEVEL_VOL=$PWD
TOPLEVEL_DIR=/root/go/src/github.com/skydive-project/$(basename $TOPLEVEL_VOL)

function version() {
    define=""
    commit=`git rev-parse --verify HEAD`
    tagname=`git show-ref --tags | grep $commit || true`
    if [ -n "$tagname" ]; then
            define=`echo $tagname | awk -F "/" '{print \$NF}' | tr -d "[a-z]"`
    else
            version=`(git describe --abbrev=0 --tags || echo v0.0.0) | tr -d "[a-z]"`
            define=`printf "$version-%.12s" $commit`
    fi
    tainted=`git ls-files -m | wc -l`
    if [ "$tainted" -gt 0 ]; then
            define="${define}-tainted"
    fi
    echo $define
}

[ -z "$DOCKER_TAG_SNAPSHOT" ] && DOCKER_TAG_SNAPSHOT=$(version)

docker_tag_with_arch() {
    local tag=$1
    local arch=$2
    echo ${tag}-linux-${arch}
}

docker_tag() {
    local arch=$1
    docker_tag_with_arch $DOCKER_TAG $arch
}

docker_tag_snapshot() {
    local arch=$1
    docker_tag_with_arch $DOCKER_TAG_SNAPSHOT $arch
}

docker_skydive_builder() {
    local arch=$1
    local dockerfile=$2
    local src=$3
    local dst=$4

    # create docker image of builder and build skydive
    local tag=skydive-compile
    local image=skydive-compile-build
    local uid=$( id -u )
    local docker_dir=$( dirname ${dockerfile} )
    docker build -t $tag \
        ${TARGET_ARCH:+--build-arg TARGET_ARCH=${TARGET_ARCH}} \
        ${TARGET_GOARCH:+--build-arg TARGET_GOARCH=${TARGET_GOARCH}} \
        ${DEBARCH:+--build-arg DEBARCH=${DEBARCH}} \
        --build-arg UID=$uid \
        --build-arg PROJECT=$( basename ${TOPLEVEL_DIR} ) \
        -f $dockerfile $docker_dir
    docker volume create $GOMOD_VOL
    docker volume create $GOBUILD_VOL
    docker rm $image || true
    eval docker run --name $image \
        --env UID=$uid \
        --env GOPATH=$GOPATH_DIR \
        --env CC=$TARGET_ARCH-linux-gnu-gcc \
        --env GOARCH=$TARGET_GOARCH \
        --volume $TOPLEVEL_VOL:$TOPLEVEL_DIR \
        --volume $GOMOD_VOL:$GOMOD_DIR \
        --volume $GOBUILD_VOL:$GOBUILD_DIR \
        $tag ${DOCKER_BUILD_COMMAND}

    # copy executable out of builder docker image
    local src=/root/go/bin/${DOCKER_BINARY}
    local dst=$( dirname ${DOCKERFILE} )/$( basename ${DOCKER_BINARY} ).$arch
    docker cp $image:$src $dst

    docker rm $image
}

docker_skydive_target() {
    local arch=$1
    local dockerfile=$2

    # build target skydive docker image
    local image=$( docker_image ${arch} )
    docker build -t $image \
        --label "Version=${VERSION}" \
        --build-arg ARCH=$arch \
        ${BASE:+--build-arg BASE=${BASE}} \
        -f $dockerfile $( dirname ${dockerfile} )
    if [ "$VERSION" = latest ]; then
        local image_snapshot=$( docker_image_snapshot ${arch} )
        docker tag $image $image_snapshot
    fi
}

docker_native_build() {
    local arch=$1

    docker_skydive_builder $arch $DIR/Dockerfile.compile

    docker_skydive_target $arch $DOCKERFILE
}

docker_cross_build() {
    local arch=$1

    docker_skydive_builder $arch $DIR/Dockerfile.crosscompile

    docker_skydive_target $arch $DOCKERFILE
}

docker_build() {
    for arch in $ARCHES
    do
        case $arch in
          amd64)
            TARGET_GOARCH=$arch TARGET_ARCH=x86_64 docker_native_build $arch
            ;;
          ppc64le)
            TARGET_GOARCH=$arch TARGET_ARCH=powerpc64le DEBARCH=ppc64el BASE=${arch}/ubuntu docker_cross_build $arch
            ;;
          arm64)
            TARGET_GOARCH=$arch TARGET_ARCH=aarch64 DEBARCH=$arch BASE=aarch64/ubuntu docker_cross_build $arch
            ;;
          s390x)
            TARGET_GOARCH=$arch TARGET_ARCH=$arch DEBARCH=$arch BASE=${arch}/ubuntu docker_cross_build $arch
            ;;
          *)
            TARGET_GOARCH=$arch TARGET_ARCH=$arch DEBARCH=$arch BASE=${arch}/ubuntu docker_cross_build $arch
            ;;
        esac
    done
}

docker_login() {
    set +x
    if [ -z "$DOCKER_PASSWORD" ]; then
        echo "The environment variable DOCKER_PASSWORD needs to be defined"
        exit 1
    fi

    echo "${DOCKER_PASSWORD}" | docker login  --username "${DOCKER_USERNAME}" --password-stdin ${DOCKER_SERVER}
    set -x
}

docker_image() {
    local arch=$1
    echo ${DOCKER_IMAGE}:$( docker_tag ${arch} )
}

docker_image_snapshot() {
    local arch=$1
    echo ${DOCKER_IMAGE_SNAPSHOT}:$( docker_tag_snapshot ${arch} )
}

docker_inspect() {
    local arch=$1
    docker inspect --format='{{index .RepoDigests 0}}' $( docker_image ${arch} )
}

docker_push() {
    for arch in $ARCHES
    do
        docker push $( docker_image ${arch} )
        if [ "$VERSION" = latest ]; then
            docker push $( docker_image_snapshot ${arch} )
        fi
    done
}

docker_manifest_create_and_push() {
    local image=$1
    digests=""
    for arch in $ARCHES
    do
        digest=$( docker_inspect ${arch} )
        digests="${digests} $digest"
    done

    res=0
    for i in {1..6}
    do
        docker manifest create --amend "${image}" ${digests} && break || res=$?
        sleep 10
    done
    [ $res != 0 ] && exit $res

    for arch in $ARCHES
    do
        digest=$( docker_inspect ${arch} )
        docker manifest annotate --arch $arch "${image}" $digest
    done

    docker manifest inspect "${image}"
    docker manifest push --purge "${image}"
}

docker_manifest() {
    docker_manifest_create_and_push ${DOCKER_IMAGE}:${DOCKER_TAG}
    if [ "$VERSION" = latest ]; then
        docker_manifest_create_and_push ${DOCKER_IMAGE_SNAPSHOT}:${DOCKER_TAG_SNAPSHOT}
    fi
}
