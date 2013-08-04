#/bin/sh

# build.sh "-ck-nehalem" "3.10.3" 1
# build.sh "" "3.10.3" 2

export KERNEL_PACKAGE=$1
export KERNEL_VERSION=$2
export KERNEL_REVISION=$3
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

export SPL_PKG_VERSION="${SPL_CHANGESET}_${KERNEL_VERSION}"
export ZFS_PKG_VERSION="${ZFS_CHANGESET}_${KERNEL_VERSION}"

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
    makepkg
    
    package_file=$(ls -1 | grep ".pkg.tar.xz")
    package_path="${package_build_dir}/${package_file}"
    
    sudo pacman -U "${package_path}"
done