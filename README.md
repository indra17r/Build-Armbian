# Armbian

Ubuntu and Debian images for ARM based single-board computers
https://www.armbian.com

## How to build my own image or kernel?

Supported build environments:

- [Ubuntu Xenial 16.04 x64](http://archive.ubuntu.com/ubuntu/dists/xenial-updates/main/installer-amd64/current/images/netboot/mini.iso) guest inside a [VirtualBox](https://www.virtualbox.org/wiki/Downloads) or other virtualization software,
- [Ubuntu Xenial 16.04 x64](http://archive.ubuntu.com/ubuntu/dists/xenial-updates/main/installer-amd64/current/images/netboot/mini.iso) guest managed by [Vagrant](https://www.vagrantup.com/). This uses Virtualbox (as above) but does so in an easily repeatable way. Please check the [Armbian with Vagrant README](https://docs.armbian.com/Developer-Guide_Using-Vagrant/) for a quick start HOWTO,
- [Ubuntu Xenial 16.04 x64](http://archive.ubuntu.com/ubuntu/dists/xenial-updates/main/installer-amd64/current/images/netboot/mini.iso) inside a [Docker](https://www.docker.com/), [systemd-nspawn](https://www.freedesktop.org/software/systemd/man/systemd-nspawn.html) or other container environment [(example)](https://github.com/igorpecovnik/lib/pull/255#issuecomment-205045273). Building full OS images inside containers may not work, so this option is mostly for the kernel compilation,
- [Ubuntu Xenial 16.04 x64](http://archive.ubuntu.com/ubuntu/dists/xenial-updates/main/installer-amd64/current/images/netboot/mini.iso) running natively on a dedicated PC or a server (**not** recommended unless you build kernel only, for full OS images always use virtualization as outlined above),
- **20GB disk space** or more and **2GB RAM** or more available for the VM, container or native OS,
- superuser rights (configured `sudo` or root access).

**Execution**

	apt-get -y install git
	git clone https://github.com/150balbes/Build-Armbian
	cd build
	./compile.sh

Make sure that full path to the build script does not contain spaces.

You will be prompted with a selection menu for a build option, a board name, a kernel branch and an OS release. 
Please check the documentation for [advanced options](https://docs.armbian.com/Developer-Guide_Build-Options/) and [additional customization](https://docs.armbian.com/Developer-Guide_User-Configurations/).

Build process uses caching for the compilation and the debootstrap process, so consecutive runs with similar settings will be much faster.

## Reporting issues

Please read [this](https://github.com/150balbes/lib/blob/master/.github/ISSUE_TEMPLATE.md) notice first before opening an issue.

## More info:

- [Documentation](https://docs.armbian.com/Developer-Guide_Build-Preparation/)
- [Prebuilt images](https://www.armbian.com/download/)
- [Support forums](https://forum.armbian.com/ "Armbian support forum")
- [Project at Github](https://github.com/igorpecovnik/lib)
