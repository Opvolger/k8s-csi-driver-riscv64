# newest release-X.Y branch of a git repo (override a *_BRANCH variable to use a fixed branch)
latest_release_branch = $(or $(shell git ls-remote --heads $(1) 'release-*' | sed -n 's|.*refs/heads/\(release-[0-9]*\.[0-9]*\)$$|\1|p' | sort -V | tail -1),$(error no release branch found for $(1)))
# newest vX.Y.Z release tag of a git repo, without pre-releases (override a *_TAG variable to use a fixed tag)
latest_release_tag = $(or $(shell git ls-remote --tags --refs $(1) 'v*' | sed -n 's|.*refs/tags/\(v[0-9]*\.[0-9]*\.[0-9]*\)$$|\1|p' | sort -V | tail -1),$(error no release tag found for $(1)))

# k8s release
RELEASE_BRANCH ?= master
RELEASE_REPO ?= https://github.com/kubernetes/release.git
# upstream debian-base builds with 'docker build --platform', riscv64 only has to be added to PLATFORMS
RELEASE_PATCHES ?= patches/release
RELEASE_ALL_ARCH ?= s390x arm ppc64le amd64 arm64 riscv64
# debian-base image that is built and replaces registry.k8s.io/build-image/debian-base in the Dockerfiles
DEBIAN_BASE_CONFIG ?= trixie
DEBIAN_BASE_VERSION ?= trixie-v1.0.0
DEBIAN_BASE_IMAGE = $(DOCKER_REGISTRY_NAME)/debian-base:$(DEBIAN_BASE_VERSION)

# node-driver-registrar
NODE_DRIVER_REGISTRAR_BRANCH ?= $(call latest_release_branch,$(NODE_DRIVER_REGISTRAR_REPO))
NODE_DRIVER_REGISTRAR_REPO ?= https://github.com/kubernetes-csi/node-driver-registrar
NODE_DRIVER_REGISTRAR_PATCHES ?= patches/node-driver-registrar

# livenessprobe
LIVENESSPROBE_BRANCH ?= $(call latest_release_branch,$(LIVENESSPROBE_REPO))
LIVENESSPROBE_REPO ?= https://github.com/kubernetes-csi/livenessprobe.git
LIVENESSPROBE_PATCHES ?= patches/livenessprobe

# csi-driver-iscsi
CSI_DRIVER_ISCSI_BRANCH ?= master
CSI_DRIVER_ISCSI_REPO ?= https://github.com/kubernetes-csi/csi-driver-iscsi.git
CSI_DRIVER_ISCSI_PATCHES ?= patches/csi-driver-iscsi

# csi-driver-smb
CSI_DRIVER_SMB_BRANCH ?= $(call latest_release_branch,$(CSI_DRIVER_SMB_REPO))
CSI_DRIVER_SMB_REPO ?= https://github.com/kubernetes-csi/csi-driver-smb.git
CSI_DRIVER_SMB_PATCHES ?= patches/csi-driver-smb
CSI_DRIVER_SMB_ARCHS ?= amd64 riscv64 arm64
CSI_DRIVER_SMB_WINDOWS ?= 1809 ltsc2022

# csi-provisioner
CSI_PROVISIONER_BRANCH ?= $(call latest_release_branch,$(CSI_PROVISIONER_REPO))
CSI_PROVISIONER_REPO ?= https://github.com/kubernetes-csi/external-provisioner.git
CSI_PROVISIONER_PATCHES ?= patches/external-provisioner

# csi-resizer
CSI_RESIZER_BRANCH ?= $(call latest_release_branch,$(CSI_RESIZER_REPO))
CSI_RESIZER_REPO ?= https://github.com/kubernetes-csi/external-resizer.git
CSI_RESIZER_PATCHES ?= patches/external-resizer

# csi-driver-nfs
CSI_DRIVER_NFS_BRANCH ?= $(call latest_release_branch,$(CSI_DRIVER_NFS_REPO))
# empty: use the IMAGE_VERSION of the csi-driver-nfs Makefile (latest release of the branch)
CSI_DRIVER_NFS_VERSION ?=
CSI_DRIVER_NFS_ARCHS ?= amd64 riscv64 arm64
CSI_DRIVER_NFS_REPO ?= https://github.com/kubernetes-csi/csi-driver-nfs.git
CSI_DRIVER_NFS_PATCHES ?= patches/csi-driver-nfs

# gives csi-snapshotter, snapshot-controller and snapshot-conversion-webhook
EXTERNAL_SNAPSHOTTER_BRANCH ?= $(call latest_release_branch,$(EXTERNAL_SNAPSHOTTER_REPO))
EXTERNAL_SNAPSHOTTER_REPO ?= https://github.com/kubernetes-csi/external-snapshotter.git
EXTERNAL_SNAPSHOTTER_PATCHES ?= patches/external-snapshotter

# gives cert-manager-controller, -cainjector, -webhook, -acmesolver and -startupapicheck (built with ko)
CERT_MANAGER_TAG ?= $(call latest_release_tag,$(CERT_MANAGER_REPO))
CERT_MANAGER_REPO ?= https://github.com/cert-manager/cert-manager.git
CERT_MANAGER_PATCHES ?= patches/cert-manager
CERT_MANAGER_BINS ?= controller cainjector webhook acmesolver startupapicheck
CERT_MANAGER_PLATFORMS ?= linux/amd64,linux/arm64,linux/riscv64

# cert-manager-webhook-transip
CERT_MANAGER_WEBHOOK_TRANSIP_TAG ?= $(call latest_release_tag,$(CERT_MANAGER_WEBHOOK_TRANSIP_REPO))
CERT_MANAGER_WEBHOOK_TRANSIP_REPO ?= https://github.com/demeesterdev/cert-manager-webhook-transip.git
CERT_MANAGER_WEBHOOK_TRANSIP_PATCHES ?= patches/cert-manager-webhook-transip
CERT_MANAGER_WEBHOOK_TRANSIP_PLATFORMS ?= linux/amd64,linux/arm64,linux/riscv64

DOCKER_REGISTRY_NAME ?= opvolger
# CI (set to true by GitHub Actions) makes the smb and nfs Makefiles use e2e-<commit> image tags
unexport CI
BUILD_PLATFORMS_LINUX_ONLY ?= "linux amd64 amd64; linux riscv64 riscv64 -riscv64; linux arm64 arm64 -arm64"
BUILD_PLATFORMS ?= "linux amd64 amd64; linux riscv64 riscv64 -riscv64; linux arm64 arm64 -arm64; windows amd64 amd64 .exe nanoserver:1809 servercore:ltsc2019; windows amd64 amd64 .exe nanoserver:ltsc2022 servercore:ltsc2022"

BUILD_ROOT ?= build/
# number of images that are built at the same time by docker_images
JOBS ?= 4

# the 3rd argument is a branch or a tag
define checkout_code_add_patches
	$(eval $@_DIR = $(1))
	$(eval $@_REPO = $(2))
	$(eval $@_BRANCH = $(3))
	$(eval $@_PATCHES = $(4))
	$(eval $@_BUILDER = multiarchimage-buildertest-$(1))
	mkdir -p $(BUILD_ROOT);
	if [ -d "$(BUILD_ROOT)/${$@_DIR}" ]; then \
		cd $(BUILD_ROOT)/${$@_DIR} && git fetch --tags --force origin && { git switch ${$@_BRANCH} 2>/dev/null || git switch -f --detach ${$@_BRANCH}; }; \
	else \
		cd $(BUILD_ROOT) && git clone -b ${$@_BRANCH} ${$@_REPO}; \
	fi
	echo ${$@_BRANCH}
	cd $(BUILD_ROOT)/${$@_DIR} && git clean -fd && git reset --hard $$(git rev-parse -q --verify origin/${$@_BRANCH} || echo ${$@_BRANCH})
	cd $(BUILD_ROOT)/${$@_DIR} && git apply --ignore-whitespace --whitespace=fix ../../${$@_PATCHES}/*.patch || echo "no patches or error!"
	# use our own (riscv64) debian-base image instead of the upstream one
	cd $(BUILD_ROOT)/${$@_DIR} && git grep -lE '^FROM registry.k8s.io/build-image/debian-base:' -- '*Dockerfile*' ':!vendor' | xargs -r sed -i -E 's#^FROM registry.k8s.io/build-image/debian-base:[^[:space:]]+#FROM $(DEBIAN_BASE_IMAGE)#'
	# give every repo its own buildx builder, so they can be built in parallel
	cd $(BUILD_ROOT)/${$@_DIR} && if [ -f release-tools/build.make ]; then sed -i 's/multiarchimage-buildertest/${$@_BUILDER}/g' release-tools/build.make; fi
endef

# debian-base (docker_release) is needed by iscsi, smb and nfs, so build it first.
# After that all other images are built in parallel (JOBS at a time).
# 'docker buildx create --use' changes the builder for everyone, so every build pins its own builder with BUILDX_BUILDER.
docker_images: docker_release
	$(MAKE) -j$(JOBS) --output-sync=target docker_images_parallel

# qemu, needed to build images for other architectures
binfmt:
	docker run --privileged --rm tonistiigi/binfmt --install all

docker_images_parallel: docker_csi_node_driver_registrar docker_csi_driver_iscsi docker_livenessprobe docker_csi_driver_smb docker_csi_provisioner docker_csi_resizer docker_csi_driver_nfs docker_external_snapshotter docker_cert_manager docker_cert_manager_webhook_transip

# the debian-base build runs commands in the image of every platform, so it needs qemu (binfmt)
docker_release: binfmt
	@$(call checkout_code_add_patches,release,${RELEASE_REPO},${RELEASE_BRANCH},${RELEASE_PATCHES})
	$(MAKE) -j1 -C $(BUILD_ROOT)/${$@_DIR}/images/build/debian-base push CONFIG="$(DEBIAN_BASE_CONFIG)" IMAGE_VERSION="$(DEBIAN_BASE_VERSION)" PLATFORMS="$(addprefix linux/,$(RELEASE_ALL_ARCH))" REGISTRY=$(DOCKER_REGISTRY_NAME)
	# not the upstream 'manifest' target: 'docker manifest create' fails on the image indexes (with attestations)
	# that newer docker versions (containerd image store) push, 'buildx imagetools create' handles them
	docker buildx imagetools create -t $(DEBIAN_BASE_IMAGE) $(foreach arch,$(RELEASE_ALL_ARCH),$(DOCKER_REGISTRY_NAME)/debian-base-$(arch):$(DEBIAN_BASE_VERSION))

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
	version="$(CSI_DRIVER_NFS_VERSION)"; \
	[ -n "$$version" ] || version=$$(sed -n 's/^IMAGE_VERSION ?= *\([^[:space:]]*\).*/\1/p' $(BUILD_ROOT)/${$@_DIR}/Makefile); \
	image=$(DOCKER_REGISTRY_NAME)/nfsplugin:$$version; \
	echo "building $$image"; \
	for arch in $(CSI_DRIVER_NFS_ARCHS); do \
		$(MAKE) -j1 -C $(BUILD_ROOT)/${$@_DIR} nfs ARCH=$$arch IMAGE_VERSION=$$version && \
		BUILDX_BUILDER=default $(MAKE) -j1 -C $(BUILD_ROOT)/${$@_DIR} container-build ARCH=$$arch REGISTRY=$(DOCKER_REGISTRY_NAME) IMAGE_VERSION=$$version && \
		docker push $$image-linux-$$arch || exit 1; \
	done; \
	docker manifest create --amend $$image $(foreach arch,$(CSI_DRIVER_NFS_ARCHS),$$image-linux-$(arch)) && \
	docker manifest push --purge $$image

docker_external_snapshotter:
	@$(call checkout_code_add_patches,external-snapshotter,${EXTERNAL_SNAPSHOTTER_REPO},${EXTERNAL_SNAPSHOTTER_BRANCH},${EXTERNAL_SNAPSHOTTER_PATCHES})
	BUILDX_BUILDER=${$@_BUILDER} $(MAKE) -j1 -C $(BUILD_ROOT)/${$@_DIR} push-multiarch PULL_BASE_REF=${$@_BRANCH} REGISTRY_NAME=$(DOCKER_REGISTRY_NAME) BUILD_PLATFORMS=$(BUILD_PLATFORMS)

# cert-manager builds its images with ko (make ko-images-push), the image tag is the git tag (e.g. v1.21.2)
docker_cert_manager:
	@$(call checkout_code_add_patches,cert-manager,${CERT_MANAGER_REPO},${CERT_MANAGER_TAG},${CERT_MANAGER_PATCHES})
	$(MAKE) -j1 -C $(BUILD_ROOT)/${$@_DIR} go-workspace
	$(MAKE) -j1 -C $(BUILD_ROOT)/${$@_DIR} ko-images-push KO_REGISTRY=$(DOCKER_REGISTRY_NAME) KO_PLATFORM=$(CERT_MANAGER_PLATFORMS) KO_BINS="$(CERT_MANAGER_BINS)"

# image tags: the git tag (e.g. v0.1.4) and the version without 'v' (e.g. 0.1.4, used by the helm chart)
docker_cert_manager_webhook_transip:
	@$(call checkout_code_add_patches,cert-manager-webhook-transip,${CERT_MANAGER_WEBHOOK_TRANSIP_REPO},${CERT_MANAGER_WEBHOOK_TRANSIP_TAG},${CERT_MANAGER_WEBHOOK_TRANSIP_PATCHES})
	docker buildx rm ${$@_BUILDER} || true
	docker buildx create --name ${$@_BUILDER}
	tag=${$@_BRANCH}; image=$(DOCKER_REGISTRY_NAME)/cert-manager-webhook-transip; \
	docker buildx build --builder ${$@_BUILDER} --push --platform $(CERT_MANAGER_WEBHOOK_TRANSIP_PLATFORMS) \
		-t $$image:$$tag -t $$image:$${tag#v} $(BUILD_ROOT)/${$@_DIR}
	docker buildx rm ${$@_BUILDER}
