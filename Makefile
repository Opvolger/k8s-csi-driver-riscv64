# k8s release
RELEASE_BRANCH ?= master
RELEASE_REPO ?= https://github.com/kubernetes/release.git
RELEASE_PATCHES ?= patches/release
RELEASE_ALL_ARCH ?= s390x arm ppc64le amd64 arm64 riscv64

# node-driver-registrar
NODE_DRIVER_REGISTRAR_BRANCH ?= release-2.18
NODE_DRIVER_REGISTRAR_REPO ?= https://github.com/kubernetes-csi/node-driver-registrar
NODE_DRIVER_REGISTRAR_PATCHES ?= patches/node-driver-registrar

# livenessprobe
LIVENESSPROBE_BRANCH ?= release-2.20
LIVENESSPROBE_REPO ?= https://github.com/kubernetes-csi/livenessprobe.git
LIVENESSPROBE_PATCHES ?= patches/livenessprobe

# csi-driver-iscsi
CSI_DRIVER_ISCSI_BRANCH ?= master
CSI_DRIVER_ISCSI_REPO ?= https://github.com/kubernetes-csi/csi-driver-iscsi.git
CSI_DRIVER_ISCSI_PATCHES ?= patches/csi-driver-iscsi

# csi-driver-smb
CSI_DRIVER_SMB_BRANCH ?= release-1.20
CSI_DRIVER_SMB_REPO ?= https://github.com/kubernetes-csi/csi-driver-smb.git
CSI_DRIVER_SMB_PATCHES ?= patches/csi-driver-smb
CSI_DRIVER_SMB_ARCHS ?= amd64 riscv64 arm64
CSI_DRIVER_SMB_WINDOWS ?= 1809 ltsc2022

# csi-provisioner
CSI_PROVISIONER_BRANCH ?= release-6.3
CSI_PROVISIONER_REPO ?= https://github.com/kubernetes-csi/external-provisioner.git
CSI_PROVISIONER_PATCHES ?= patches/external-provisioner

# csi-resizer
CSI_RESIZER_BRANCH ?= release-2.3
CSI_RESIZER_REPO ?= https://github.com/kubernetes-csi/external-resizer.git
CSI_RESIZER_PATCHES ?= patches/external-resizer

# csi-driver-nfs
CSI_DRIVER_NFS_BRANCH ?= release-4.13
CSI_DRIVER_NFS_VERSION ?= v4.13.4
CSI_DRIVER_NFS_ARCHS ?= amd64 riscv64 arm64
CSI_DRIVER_NFS_IMAGE = $(DOCKER_REGISTRY_NAME)/nfsplugin:$(CSI_DRIVER_NFS_VERSION)
CSI_DRIVER_NFS_REPO ?= https://github.com/kubernetes-csi/csi-driver-nfs.git
CSI_DRIVER_NFS_PATCHES ?= patches/csi-driver-nfs

# gives csi-snapshotter, snapshot-controller and snapshot-conversion-webhook
EXTERNAL_SNAPSHOTTER_BRANCH ?= release-8.6
EXTERNAL_SNAPSHOTTER_REPO ?= https://github.com/kubernetes-csi/external-snapshotter.git
EXTERNAL_SNAPSHOTTER_PATCHES ?= patches/external-snapshotter

DOCKER_REGISTRY_NAME ?= opvolger
BUILD_PLATFORMS_LINUX_ONLY ?= "linux amd64 amd64; linux riscv64 riscv64 -riscv64; linux arm64 arm64 -arm64"
BUILD_PLATFORMS ?= "linux amd64 amd64; linux riscv64 riscv64 -riscv64; linux arm64 arm64 -arm64; windows amd64 amd64 .exe nanoserver:1809 servercore:ltsc2019; windows amd64 amd64 .exe nanoserver:ltsc2022 servercore:ltsc2022"

BUILD_ROOT ?= build/
# number of images that are built at the same time by docker_images
JOBS ?= 4

define checkout_code_add_patches
	$(eval $@_DIR = $(1))
	$(eval $@_REPO = $(2))
	$(eval $@_BRANCH = $(3))
	$(eval $@_PATCHES = $(4))
	$(eval $@_BUILDER = multiarchimage-buildertest-$(1))
	mkdir -p $(BUILD_ROOT);
	if [ -d "$(BUILD_ROOT)/${$@_DIR}" ]; then \
		cd $(BUILD_ROOT)/${$@_DIR} && git switch ${$@_BRANCH}; \
	else \
		cd $(BUILD_ROOT) && git clone -b ${$@_BRANCH} ${$@_REPO}; \
	fi
	echo ${$@_BRANCH}
	cd $(BUILD_ROOT)/${$@_DIR} && git clean -fd && git reset --hard
	cd $(BUILD_ROOT)/${$@_DIR} && git apply --ignore-whitespace --whitespace=fix ../../${$@_PATCHES}/*.patch || echo "no patches or error!"
	# give every repo its own buildx builder, so they can be built in parallel
	cd $(BUILD_ROOT)/${$@_DIR} && if [ -f release-tools/build.make ]; then sed -i 's/multiarchimage-buildertest/${$@_BUILDER}/g' release-tools/build.make; fi
endef

# debian-base (docker_release) is needed by iscsi, smb and nfs, and resets qemu, so build it first.
# After that all other images are built in parallel (JOBS at a time).
# 'docker buildx create --use' changes the builder for everyone, so every build pins its own builder with BUILDX_BUILDER.
docker_images: docker_release binfmt
	$(MAKE) -j$(JOBS) --output-sync=target docker_images_parallel

# qemu, needed to build images for other architectures
binfmt:
	docker run --privileged --rm tonistiigi/binfmt --install all

docker_images_parallel: docker_csi_node_driver_registrar docker_csi_driver_iscsi docker_livenessprobe docker_csi_driver_smb docker_csi_provisioner docker_csi_resizer docker_csi_driver_nfs docker_external_snapshotter

docker_release:
	@$(call checkout_code_add_patches,release,${RELEASE_REPO},${RELEASE_BRANCH},${RELEASE_PATCHES})
	$(MAKE) -j1 -C $(BUILD_ROOT)/${$@_DIR}/images/build/debian-base all-push CONFIG="trixie" IMAGE_VERSION="trixie-v1.0.0" ALL_ARCH="$(RELEASE_ALL_ARCH)" REGISTRY=$(DOCKER_REGISTRY_NAME)

docker_csi_node_driver_registrar:
	@$(call checkout_code_add_patches,node-driver-registrar,${NODE_DRIVER_REGISTRAR_REPO},${NODE_DRIVER_REGISTRAR_BRANCH},${NODE_DRIVER_REGISTRAR_PATCHES})
	BUILDX_BUILDER=${$@_BUILDER} $(MAKE) -j1 -C $(BUILD_ROOT)/${$@_DIR} push-multiarch PULL_BASE_REF=${$@_BRANCH} REGISTRY_NAME=$(DOCKER_REGISTRY_NAME) BUILD_PLATFORMS=$(BUILD_PLATFORMS)

docker_csi_driver_iscsi:
	@$(call checkout_code_add_patches,csi-driver-iscsi,${CSI_DRIVER_ISCSI_REPO},${CSI_DRIVER_ISCSI_BRANCH},${CSI_DRIVER_ISCSI_PATCHES})
	BUILDX_BUILDER=${$@_BUILDER} $(MAKE) -j1 -C $(BUILD_ROOT)/${$@_DIR} push-multiarch PULL_BASE_REF=${$@_BRANCH} REGISTRY_NAME=$(DOCKER_REGISTRY_NAME) BUILD_PLATFORMS=$(BUILD_PLATFORMS_LINUX_ONLY)

docker_livenessprobe:
	@$(call checkout_code_add_patches,livenessprobe,${LIVENESSPROBE_REPO},${LIVENESSPROBE_BRANCH},${LIVENESSPROBE_PATCHES})
	BUILDX_BUILDER=${$@_BUILDER} $(MAKE) -j1 -C $(BUILD_ROOT)/${$@_DIR} push-multiarch PULL_BASE_REF=${$@_BRANCH} REGISTRY_NAME=$(DOCKER_REGISTRY_NAME) BUILD_PLATFORMS=$(BUILD_PLATFORMS)

docker_csi_driver_smb:
	@$(call checkout_code_add_patches,csi-driver-smb,${CSI_DRIVER_SMB_REPO},${CSI_DRIVER_SMB_BRANCH},${CSI_DRIVER_SMB_PATCHES})
	docker buildx rm smb-builder || true
	docker buildx create --name smb-builder
	for arch in $(CSI_DRIVER_SMB_ARCHS); do \
		$(MAKE) -j1 -C $(BUILD_ROOT)/${$@_DIR} smb ARCH=$$arch && \
		BUILDX_BUILDER=smb-builder $(MAKE) -j1 -C $(BUILD_ROOT)/${$@_DIR} container-linux ARCH=$$arch REGISTRY=$(DOCKER_REGISTRY_NAME) IMAGENAME=smbplugin || exit 1; \
	done
	for osversion in $(CSI_DRIVER_SMB_WINDOWS); do \
		$(MAKE) -j1 -C $(BUILD_ROOT)/${$@_DIR} smb-windows ARCH=amd64 && \
		BUILDX_BUILDER=smb-builder $(MAKE) -j1 -C $(BUILD_ROOT)/${$@_DIR} container-windows ARCH=amd64 OSVERSION=$$osversion REGISTRY=$(DOCKER_REGISTRY_NAME) IMAGENAME=smbplugin || exit 1; \
	done
	docker buildx rm smb-builder
	$(MAKE) -j1 -C $(BUILD_ROOT)/${$@_DIR} push-manifest REGISTRY=$(DOCKER_REGISTRY_NAME) IMAGENAME=smbplugin ALL_OS_ARCH.linux="$(addprefix linux-,$(CSI_DRIVER_SMB_ARCHS))" ALL_OSVERSIONS.windows="$(CSI_DRIVER_SMB_WINDOWS)"

docker_csi_provisioner:
	@$(call checkout_code_add_patches,external-provisioner,${CSI_PROVISIONER_REPO},${CSI_PROVISIONER_BRANCH},${CSI_PROVISIONER_PATCHES})
	BUILDX_BUILDER=${$@_BUILDER} $(MAKE) -j1 -C $(BUILD_ROOT)/${$@_DIR} push-multiarch PULL_BASE_REF=${$@_BRANCH} REGISTRY_NAME=$(DOCKER_REGISTRY_NAME) BUILD_PLATFORMS=$(BUILD_PLATFORMS_LINUX_ONLY)

docker_csi_resizer:
	@$(call checkout_code_add_patches,external-resizer,${CSI_RESIZER_REPO},${CSI_RESIZER_BRANCH},${CSI_RESIZER_PATCHES})
	BUILDX_BUILDER=${$@_BUILDER} $(MAKE) -j1 -C $(BUILD_ROOT)/${$@_DIR} push-multiarch PULL_BASE_REF=${$@_BRANCH} REGISTRY_NAME=$(DOCKER_REGISTRY_NAME) BUILD_PLATFORMS=$(BUILD_PLATFORMS_LINUX_ONLY)

docker_csi_driver_nfs:
	@$(call checkout_code_add_patches,csi-driver-nfs,${CSI_DRIVER_NFS_REPO},${CSI_DRIVER_NFS_BRANCH},${CSI_DRIVER_NFS_PATCHES})
	for arch in $(CSI_DRIVER_NFS_ARCHS); do \
		$(MAKE) -j1 -C $(BUILD_ROOT)/${$@_DIR} nfs ARCH=$$arch IMAGE_VERSION=$(CSI_DRIVER_NFS_VERSION) && \
		BUILDX_BUILDER=default $(MAKE) -j1 -C $(BUILD_ROOT)/${$@_DIR} container-build ARCH=$$arch REGISTRY=$(DOCKER_REGISTRY_NAME) IMAGE_VERSION=$(CSI_DRIVER_NFS_VERSION) CI= && \
		docker push $(CSI_DRIVER_NFS_IMAGE)-linux-$$arch || exit 1; \
	done
	docker manifest create --amend $(CSI_DRIVER_NFS_IMAGE) $(foreach arch,$(CSI_DRIVER_NFS_ARCHS),$(CSI_DRIVER_NFS_IMAGE)-linux-$(arch))
	docker manifest push --purge $(CSI_DRIVER_NFS_IMAGE)

docker_external_snapshotter:
	@$(call checkout_code_add_patches,external-snapshotter,${EXTERNAL_SNAPSHOTTER_REPO},${EXTERNAL_SNAPSHOTTER_BRANCH},${EXTERNAL_SNAPSHOTTER_PATCHES})
	BUILDX_BUILDER=${$@_BUILDER} $(MAKE) -j1 -C $(BUILD_ROOT)/${$@_DIR} push-multiarch PULL_BASE_REF=${$@_BRANCH} REGISTRY_NAME=$(DOCKER_REGISTRY_NAME) BUILD_PLATFORMS=$(BUILD_PLATFORMS)
