# k8s release
RELEASE_BRANCH ?= master
RELEASE_REPO ?= https://github.com/kubernetes/release.git
RELEASE_PATCHES ?= patches/release

# node-driver-registrar
NODE_DRIVER_REGISTRAR_BRANCH ?= release-2.16
NODE_DRIVER_REGISTRAR_REPO ?= https://github.com/kubernetes-csi/node-driver-registrar
NODE_DRIVER_REGISTRAR_PATCHES ?= patches/node-driver-registrar

# livenessprobe
LIVENESSPROBE_BRANCH ?= release-2.18
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

# csi-provisioner
CSI_PROVISIONER_BRANCH ?= release-6.2
CSI_PROVISIONER_REPO ?= https://github.com/kubernetes-csi/external-provisioner.git
CSI_PROVISIONER_PATCHES ?= patches/external-provisioner

# csi-resizer
CSI_RESIZER_BRANCH ?= release-2.1
CSI_RESIZER_REPO ?= https://github.com/kubernetes-csi/external-resizer.git
CSI_RESIZER_PATCHES ?= patches/external-resizer

# csi-driver-nfs
CSI_DRIVER_NFS_BRANCH ?= release-4.13
CSI_DRIVER_NFS_REPO ?= https://github.com/kubernetes-csi/csi-driver-nfs.git
CSI_DRIVER_NFS_PATCHES ?= patches/csi-driver-nfs

# gives csi-snapshotter, snapshot-controller and snapshot-conversion-webhook
EXTERNAL_SNAPSHOTTER_BRANCH ?= release-8.5
EXTERNAL_SNAPSHOTTER_REPO ?= https://github.com/kubernetes-csi/external-snapshotter.git
EXTERNAL_SNAPSHOTTER_PATCHES ?= patches/external-snapshotter

DOCKER_REGISTRY_NAME ?= opvolger
BUILD_PLATFORMS_LINUX_ONLY ?= "linux amd64 amd64; linux riscv64 riscv64 -riscv64; linux arm64 arm64 -arm64"
BUILD_PLATFORMS ?= "linux amd64 amd64; linux riscv64 riscv64 -riscv64; linux arm64 arm64 -arm64; windows amd64 amd64 .exe nanoserver:1809 servercore:ltsc2019; windows amd64 amd64 .exe nanoserver:ltsc2022 servercore:ltsc2022"

BUILD_ROOT ?= build/

define checkout_code_add_patches
	$(eval $@_DIR = $(1))
	$(eval $@_REPO = $(2))
	$(eval $@_BRANCH = $(3))
	$(eval $@_PATCHES = $(4))
	mkdir -p $(BUILD_ROOT);
	if [ -d "$(BUILD_ROOT)/${$@_DIR}" ]; then \
		cd $(BUILD_ROOT)/${$@_DIR} && git switch ${$@_BRANCH}; \
	else \
		cd $(BUILD_ROOT) && git clone -b ${$@_BRANCH} ${$@_REPO}; \
	fi
	echo ${$@_BRANCH}
	cd $(BUILD_ROOT)/${$@_DIR} && git clean -fd && git reset --hard
	cd $(BUILD_ROOT)/${$@_DIR} && git apply --ignore-whitespace --whitespace=fix ../../${$@_PATCHES}/*.patch || echo "no patches or error!"
endef

docker_images: docker_release docker_csi_node_driver_registrar docker_csi_driver_iscsi docker_livenessprobe docker_csi_driver_smb docker_csi_provisioner docker_csi_resizer docker_csi_driver_nfs docker_external_snapshotter

docker_release:
	@$(call checkout_code_add_patches,"release",${RELEASE_REPO},${RELEASE_BRANCH},${RELEASE_PATCHES})
	$(MAKE) -C $(BUILD_ROOT)/${$@_DIR}/images/build/debian-base all-push CONFIG="trixie" IMAGE_VERSION="trixie-v1.0.0" ALL_ARCH="s390x arm ppc64le amd64 arm64 riscv64" REGISTRY=$(DOCKER_REGISTRY_NAME)

docker_csi_node_driver_registrar:
	@$(call checkout_code_add_patches,"node-driver-registrar",${NODE_DRIVER_REGISTRAR_REPO},${NODE_DRIVER_REGISTRAR_BRANCH},${NODE_DRIVER_REGISTRAR_PATCHES})
	$(MAKE) -C $(BUILD_ROOT)/${$@_DIR} push-multiarch PULL_BASE_REF=${$@_BRANCH} REGISTRY_NAME=$(DOCKER_REGISTRY_NAME) BUILD_PLATFORMS=$(BUILD_PLATFORMS)

docker_csi_driver_iscsi:
	@$(call checkout_code_add_patches,"csi-driver-iscsi",${CSI_DRIVER_ISCSI_REPO},${CSI_DRIVER_ISCSI_BRANCH},${CSI_DRIVER_ISCSI_PATCHES})
	$(MAKE) -C $(BUILD_ROOT)/${$@_DIR} push-multiarch PULL_BASE_REF=${$@_BRANCH} REGISTRY_NAME=$(DOCKER_REGISTRY_NAME) BUILD_PLATFORMS=$(BUILD_PLATFORMS_LINUX_ONLY)

docker_livenessprobe:
	@$(call checkout_code_add_patches,"livenessprobe",${LIVENESSPROBE_REPO},${LIVENESSPROBE_BRANCH},${LIVENESSPROBE_PATCHES})
	$(MAKE) -C $(BUILD_ROOT)/${$@_DIR} push-multiarch PULL_BASE_REF=${$@_BRANCH} REGISTRY_NAME=$(DOCKER_REGISTRY_NAME) BUILD_PLATFORMS=$(BUILD_PLATFORMS)

docker_csi_driver_smb:
	@$(call checkout_code_add_patches,"csi-driver-smb",${CSI_DRIVER_SMB_REPO},${CSI_DRIVER_SMB_BRANCH},${CSI_DRIVER_SMB_PATCHES})
	$(MAKE) -C $(BUILD_ROOT)/${$@_DIR} container-all REGISTRY=$(DOCKER_REGISTRY_NAME) IMAGENAME=smbplugin ALL_OS_ARCH.linux="linux-arm64 linux-riscv64 linux-amd64"
	$(MAKE) -C $(BUILD_ROOT)/${$@_DIR} push-manifest REGISTRY=$(DOCKER_REGISTRY_NAME) IMAGENAME=smbplugin ALL_OS_ARCH.linux="linux-arm64 linux-riscv64 linux-amd64"

docker_csi_provisioner:
	@$(call checkout_code_add_patches,"external-provisioner",${CSI_PROVISIONER_REPO},${CSI_PROVISIONER_BRANCH},${CSI_PROVISIONER_PATCHES})
	$(MAKE) -C $(BUILD_ROOT)/${$@_DIR} push-multiarch PULL_BASE_REF=${$@_BRANCH} REGISTRY_NAME=$(DOCKER_REGISTRY_NAME) BUILD_PLATFORMS=$(BUILD_PLATFORMS_LINUX_ONLY)

docker_csi_resizer:
	@$(call checkout_code_add_patches,"external-resizer",${CSI_RESIZER_REPO},${CSI_RESIZER_BRANCH},${CSI_RESIZER_PATCHES})
	$(MAKE) -C $(BUILD_ROOT)/${$@_DIR} push-multiarch PULL_BASE_REF=${$@_BRANCH} REGISTRY_NAME=$(DOCKER_REGISTRY_NAME) BUILD_PLATFORMS=$(BUILD_PLATFORMS_LINUX_ONLY)

docker_csi_driver_nfs:
	@$(call checkout_code_add_patches,"csi-driver-nfs",${CSI_DRIVER_NFS_REPO},${CSI_DRIVER_NFS_BRANCH},${CSI_DRIVER_NFS_PATCHES})
	$(MAKE) -C $(BUILD_ROOT)/${$@_DIR} nfs ARCH="amd64"
	$(MAKE) -C $(BUILD_ROOT)/${$@_DIR} nfs ARCH="riscv64"
	$(MAKE) -C $(BUILD_ROOT)/${$@_DIR} nfs ARCH="arm64"
	$(MAKE) -C $(BUILD_ROOT)/${$@_DIR} container-build ARCH="amd64" REGISTRY=$(DOCKER_REGISTRY_NAME)
	$(MAKE) -C $(BUILD_ROOT)/${$@_DIR} container-build ARCH="riscv64" REGISTRY=$(DOCKER_REGISTRY_NAME)
	$(MAKE) -C $(BUILD_ROOT)/${$@_DIR} container-build ARCH="arm64" REGISTRY=$(DOCKER_REGISTRY_NAME)
	$(MAKE) -C $(BUILD_ROOT)/${$@_DIR} push ALL_OS_ARCH="linux-arm64 linux-riscv64 linux-amd64" REGISTRY=$(DOCKER_REGISTRY_NAME)

docker_external_snapshotter:
	@$(call checkout_code_add_patches,"external-snapshotter",${EXTERNAL_SNAPSHOTTER_REPO},${EXTERNAL_SNAPSHOTTER_BRANCH},${EXTERNAL_SNAPSHOTTER_PATCHES})
	$(MAKE) -C $(BUILD_ROOT)/${$@_DIR} push-multiarch PULL_BASE_REF=${$@_BRANCH} REGISTRY_NAME=$(DOCKER_REGISTRY_NAME) BUILD_PLATFORMS=$(BUILD_PLATFORMS)
