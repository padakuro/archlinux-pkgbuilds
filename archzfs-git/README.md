archzfs-git
===========

an ugly script to automate ZFS/SPL git builds for the currently installed kernel. I used the PKGBUILD files from

[demizer/archzfs](https://github.com/demizer/archzfs)

so all credits to him for providing and maintaining them!

## Usage

General
```
./build.sh KERNEL_VARIANT
```

Example for [ck-nehalem](http://repo-ck.com/) kernel (linux-ck-nehalem=3.10.4-1)
```
./build.sh "-ck-nehalem"
```

Example for building for the ArchLinux core kernel (linux=3.10.3-3)
```
./build.sh
```

It is not possible to cross-build for different installed kernels! The kernel that is booted is the target!