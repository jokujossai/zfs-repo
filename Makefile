FEDORA := 37
KERNEL_VERSION := 6.1.14-200.fc37.x86_64
ZFS_VERSION := 2.1.9

PODMAN := podman

KERNEL_VERSION_PART := $(word 1,$(subst -, ,$(KERNEL_VERSION)))
KERNEL_RELEASE_PART := $(word 2,$(subst -, ,$(KERNEL_VERSION)))
KERNEL_BASE_URL := https://kojipkgs.fedoraproject.org//packages/kernel/$(KERNEL_VERSION_PART)/$(word 1,$(subst ., ,$(KERNEL_RELEASE_PART))).$(word 2,$(subst ., ,$(KERNEL_RELEASE_PART)))/$(word 3,$(subst ., ,$(KERNEL_RELEASE_PART)))/

src/zfs-$(ZFS_VERSION).tar.gz:
	curl -Lfs -o $@ https://github.com/openzfs/zfs/releases/download/zfs-$(ZFS_VERSION)/zfs-$(ZFS_VERSION).tar.gz

src/kernel-$(KERNEL_VERSION).rpm:
	curl -Lfs -o $@ $(subst src/,$(KERNEL_BASE_URL),$@)

src/kernel-core-$(KERNEL_VERSION).rpm:
	curl -Lfs -o $@ $(subst src/,$(KERNEL_BASE_URL),$@)

src/kernel-devel-$(KERNEL_VERSION).rpm:
	curl -Lfs -o $@ $(subst src/,$(KERNEL_BASE_URL),$@)

src/kernel-modules-$(KERNEL_VERSION).rpm:
	curl -Lfs -o $@ $(subst src/,$(KERNEL_BASE_URL),$@)

kmod-zfs-podman: src/zfs-$(ZFS_VERSION).tar.gz src/kernel-$(KERNEL_VERSION).rpm src/kernel-core-$(KERNEL_VERSION).rpm src/kernel-devel-$(KERNEL_VERSION).rpm src/kernel-modules-$(KERNEL_VERSION).rpm
	$(PODMAN) pull registry.fedoraproject.org/fedora-toolbox:$(FEDORA)
	$(PODMAN) run --rm \
		-v .:/zfs-repo:z \
		registry.fedoraproject.org/fedora-toolbox:$(FEDORA) \
		sh -c "dnf install -y -q make && make -C /zfs-repo kmod-zfs FEDORA=$(FEDORA) KERNEL_VERSION=$(KERNEL_VERSION) ZFS_VERSION=$(ZFS_VERSION)"

kmod-zfs: src/zfs-$(ZFS_VERSION).tar.gz src/kernel-$(KERNEL_VERSION).rpm src/kernel-core-$(KERNEL_VERSION).rpm src/kernel-devel-$(KERNEL_VERSION).rpm src/kernel-modules-$(KERNEL_VERSION).rpm
	dnf install -y -q \
		src/kernel-$(KERNEL_VERSION).rpm \
		src/kernel-core-$(KERNEL_VERSION).rpm \
		src/kernel-devel-$(KERNEL_VERSION).rpm \
		src/kernel-modules-$(KERNEL_VERSION).rpm
	dnf install -y -q --skip-broken epel-release gcc make autoconf automake libtool rpm-build libtirpc-devel libblkid-devel libuuid-devel libudev-devel openssl-devel zlib-devel libaio-devel libattr-devel elfutils-libelf-devel python3 python3-devel python3-setuptools python3-cffi libffi-devel git ncompress libcurl-devel
	dnf install -y -q --skip-broken --enablerepo=epel --enablerepo=powertools python3-packaging dkms
	tar -xzf src/zfs-$(ZFS_VERSION).tar.gz -C /tmp
	cd /tmp/zfs-$(ZFS_VERSION) \
		&& ./autogen.sh \
		&& ./configure \
		&& make -j`nproc` rpm-kmod
	cp /tmp/zfs-$(ZFS_VERSION)/*.rpm rpm/
	dnf install -y -q createrepo
	createrepo rpm

