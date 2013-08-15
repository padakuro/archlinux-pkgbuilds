#/bin/sh

# build.sh <KERNEL PACKAGE APPENDIX>
#
# to build for the linux-ck-nehalem package
#   build.sh "-ck-nehalem"
#
# to build for the default kernel
#   build.sh

trap "echo 'Build aborted.'; exit;" 2

KERNEL_PACKAGE=$1
KERNEL_VERSION=$(uname -r)
MAKEPKG_ARGS=$2

# strip kernel editions (eg, -ck, -pf etc. from kernel version)
if [ "$KERNEL_PACKAGE" != "" ]
then
    KERNEL_VERSION=$(echo "$KERNEL_VERSION" | cut -f1,2 -d-)
fi
# strip PKGREL from name
LINUX_VERSION=$(echo "$KERNEL_VERSION" | cut -f1 -d-)
KERNEL_PKGREL=$(echo "$KERNEL_VERSION" | cut -f2 -d-)

export KERNEL_PACKAGE
export KERNEL_VERSION

BASE_DIR=$(pwd)
BUILD_DIR=${BASE_DIR}/build
REPO_DIR=${BASE_DIR}/repo

if [ ! -d "${BUILD_DIR}" ]
then
    mkdir -p "${BUILD_DIR}"
fi

# initially clones a git repository (bare)
git_update() {
    package_name=$1
    git_url=$2
    git_repo="${REPO_DIR}/${package_name}"
    
    if [ ! -d "${git_repo}" ]
    then
        git clone --bare "${git_url}" "${git_repo}"
# don't update the repository here, it will be updated through makepkg anyway
#    else
#        cd "${git_repo}" && git pull
#        cd "${BASE_DIR}"
    fi
}

# get latest git changeset
git_changeset() {
    git_repo=$1
    
    cd "${git_repo}"
    echo $(git rev-parse --short HEAD)
}

if [ ! -d "${REPO_DIR}" ]
then
    mkdir -p "${REPO_DIR}"
fi

# initially clone the git repositories used by the spl/zfs packages
# so they only have to be cloned once
git_update "spl" "https://github.com/zfsonlinux/spl.git"
git_update "zfs" "https://github.com/zfsonlinux/zfs.git"

# retrieve their changesets and 
SPL_CHANGESET=$(git_changeset "${REPO_DIR}/spl")
ZFS_CHANGESET=$(git_changeset "${REPO_DIR}/zfs")

export SPL_PKG_VERSION="${SPL_CHANGESET}_${LINUX_VERSION}"
export ZFS_PKG_VERSION="${ZFS_CHANGESET}_${LINUX_VERSION}"

declare -a PACKAGES=('spl-utils' 'spl' 'zfs-utils' 'zfs')
for package in "${PACKAGES[@]}"
do
    # go to start directory so all paths are relative to this
    cd "${BASE_DIR}"
    
    package_name="${package}${KERNEL_PACKAGE}-git"
    package_build_dir="${BUILD_DIR}/${package_name}"
    
    # create a symlink to the source repo so it won't be cloned
    # multiple times
    if [ ! -d "${package_build_dir}" ]
    then
        mkdir -p "${package_build_dir}"
        
        case "${package_name}" in
            *spl*)
            ln -s "${REPO_DIR}/spl" "${package_build_dir}/"
            ;;
            *zfs*)
            ln -s "${REPO_DIR}/zfs" "${package_build_dir}/"
            ;;
        esac
    fi
    
    # copy template files (eg. PKGBUILD)
    cp -f template/${package}-git/* "${package_build_dir}/"
    
    # update PKGREL to match the kernel PKGREL
    sed -i "s/pkgrel=1/pkgrel=${KERNEL_PKGREL}/" "${package_build_dir}/PKGBUILD"
    
    case "${package_name}" in
        *spl*)
            echo "Building ${package_name}@${SPL_PKG_VERSION}"        
        ;;
        *zfs*)
            echo "Building ${package_name}@${ZFS_PKG_VERSION}"
        ;;
    esac
    
    # build the package and install the package
    cd "${package_build_dir}"
    makepkg $MAKEPKG_ARGS
    
    package_file=$(ls -1 | grep ".pkg.tar.xz")
    package_path="${package_build_dir}/${package_file}"
    
    sudo pacman -U "${package_path}"
done