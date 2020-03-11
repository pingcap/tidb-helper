ifdef TAG
	VERSION = $(subst v,,$(TAG))
endif

ifeq ($(shell uname -m),aarch64)
	# For download
	ARCH=arm64
	# For build rpm
	I_ARCH=aarch64
else
	# For download
	ARCH=amd64
	 # For build rpm
	I_ARCH=x86_64
endif

PROJECT_TIDB=tidb
PROJECT_TIDB_LIGHTNING=tidb-lightning
PROJECT_TIDB_TOOLS=tidb-tools
PROJECT_TIDB_CTL=tidb-ctl
PROJECT_TIDB_BINLOG=tidb-binlog
PROJECT_TIKV=tikv
PROJECT_TIKV_IMPORTER=importer
PROJECT_PD=pd
PROJECT_ETCD=etcd

ORG_PINGCAP=pingcap
ORG_TIKV=tikv

GIT_REPO_BASE_URL=https://github.com
GIT_POSTFIX=.git
GIT_URL_TIDB=$(GIT_REPO_BASE_URL)/$(ORG_PINGCAP)/$(PROJECT_TIDB)$(GIT_POSTFIX)
GIT_URL_TIKV=$(GIT_REPO_BASE_URL)/$(ORG_TIKV)/$(PROJECT_TIKV)$(GIT_POSTFIX)
GIT_URL_TIKV_IMPORTER=$(GIT_REPO_BASE_URL)/$(ORG_TIKV)/$(PROJECT_TIKV_IMPORTER)$(GIT_POSTFIX)
GIT_URL_PD=$(GIT_REPO_BASE_URL)/$(ORG_PINGCAP)/$(PROJECT_PD)$(GIT_POSTFIX)
GIT_URL_TIDB_LIGHTNING=$(GIT_REPO_BASE_URL)/$(ORG_PINGCAP)/$(PROJECT_TIDB_LIGHTNING)$(GIT_POSTFIX)
GIT_URL_TIDB_TOOLS=$(GIT_REPO_BASE_URL)/$(ORG_PINGCAP)/$(PROJECT_TIDB_TOOLS)$(GIT_POSTFIX)
GIT_URL_TIDB_CTL=$(GIT_REPO_BASE_URL)/$(ORG_PINGCAP)/$(PROJECT_TIDB_CTL)$(GIT_POSTFIX)
GIT_URL_TIDB_BINLOG=$(GIT_REPO_BASE_URL)/$(ORG_PINGCAP)/$(PROJECT_TIDB_BINLOG)$(GIT_POSTFIX)

ETCD_TAG_VER=v3.3.10
ETCD_PACKAGE_NAME=$(PROJECT_ETCD)-$(ETCD_TAG_VER)-linux-$(ARCH)
ETCD_TARBALL_NAME=$(ETCD_PACKAGE_NAME).tar.gz
ETCD_V_3_3_10_BIN_URL=$(GIT_REPO_BASE_URL)/etcd-io/etcd/releases/download/$(ETCD_TAG_VER)/$(ETCD_TARBALL_NAME)

BUILD_DIR=build
SOURCE_DIR=$(BUILD_DIR)/src

TIDB_SOURCE=$(SOURCE_DIR)/$(PROJECT_TIDB)
TIKV_SOURCE=$(SOURCE_DIR)/$(PROJECT_TIKV)
PD_SOURCE=$(SOURCE_DIR)/$(PROJECT_PD)
TIKV_IMPORTER_SOURCE=$(SOURCE_DIR)/$(PROJECT_TIKV_IMPORTER)
TIDB_CTL_SOURCE=$(SOURCE_DIR)/$(PROJECT_TIDB_CTL)
TIDB_BINLOG_SOURCE=$(SOURCE_DIR)/$(PROJECT_TIDB_BINLOG)
TIDB_LIGHTNING_SOURCE=$(SOURCE_DIR)/$(PROJECT_TIDB_LIGHTNING)
TIDB_TOOLS_SOURCE=$(SOURCE_DIR)/$(PROJECT_TIDB_TOOLS)
ETCD_BINARY_SOURCE=$(SOURCE_DIR)/$(ETCD_PACKAGE_NAME)

BINARY_DIR=$(BUILD_DIR)/bin
ARTIFACT_BINARY=$(BINARY_DIR)/$(VERSION)
ARTIFACT_BINARY_TIDB=$(ARTIFACT_BINARY)/$(PROJECT_TIDB)
ARTIFACT_BINARY_TOOLKIT=$(ARTIFACT_BINARY)/tidb-toolkit
ARTIFACT_DIR=$(BUILD_DIR)/dist

TIDB_DOCKER_IMAGE_NAME=tidb-docker
TIDB_DOCKER_IMAGE_TAG=$(ORG_PINGCAP)/$(TIDB_DOCKER_IMAGE_NAME):$(VERSION)

ARTIFACT_DOCKER=${ARTIFACT_DIR}/$(TIDB_DOCKER_IMAGE_NAME)-$(VERSION).tar.gz
ARTIFACT_PACKAGE=$(ARTIFACT_DIR)/tidb-pkg

BUILDER_PREFIX=tidb-builder
BUILDER_IMAGE_BINARY=$(ORG_PINGCAP)/$(BUILDER_PREFIX)-binary
BUILDER_IMAGE_RPM=$(ORG_PINGCAP)/$(BUILDER_PREFIX)-rpm
BUILDER_IMAGE_DEB=$(ORG_PINGCAP)/$(BUILDER_PREFIX)-deb

# make all the binary in docker. default option
BUILD_MODE_DOCKER = docker
# local: make binaries at local
BUILD_MODE_LOCAL = local
# build mode, default is docker
BUILD_MODE = $(BUILD_MODE_DOCKER)

# used for prepare docker builder image
ifeq ($(BUILD_MODE),$(BUILD_MODE_DOCKER))
	builder-prepare = docker-builder
	rpm-builder-prepare = rpm-builder
	deb-builder-prepare = deb-builder
endif

define fetch_source
	@if [ ! -d $(1)/.git ]; then\
		mkdir -p $(1); \
		git clone $(2) $(1); \
	fi
endef

define update_source_tag
	cd $(1) && git fetch $(2) tag $(3) && git checkout $(3)
endef

define update_source_branch
	cd $(1) && git fetch $(2) $(3) && git checkout $(3)
endef

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(SOURCE_DIR):
	mkdir -p $(SOURCE_DIR)

.PHONY: TIDB_SOURCE TIKV_SOURCE PD_SOURCE TIDB_LIGHTNING_SOURCE TIDB_TOOLS_SOURCE
.PHONY: TIDB_CTL_SOURCE TIDB_BINLOG_SOURCE TIKV_IMPORTER_SOURCE
# don't use directory so we can force update the projects each time.
TIDB_SOURCE: $(SOURCE_DIR)
	$(call fetch_source, $(TIDB_SOURCE),$(GIT_URL_TIDB))

TIKV_SOURCE: $(SOURCE_DIR)
	$(call fetch_source, $(TIKV_SOURCE),$(GIT_URL_TIKV))

PD_SOURCE: $(SOURCE_DIR)
	$(call fetch_source, $(PD_SOURCE),$(GIT_URL_PD))

TIDB_LIGHTNING_SOURCE: $(SOURCE_DIR)
	$(call fetch_source, $(TIDB_LIGHTNING_SOURCE), $(GIT_URL_TIDB_LIGHTNING))

TIDB_TOOLS_SOURCE: $(SOURCE_DIR)
	$(call fetch_source, $(TIDB_TOOLS_SOURCE), $(GIT_URL_TIDB_TOOLS))

TIDB_CTL_SOURCE: $(SOURCE_DIR)
	$(call fetch_source, $(TIDB_CTL_SOURCE), $(GIT_URL_TIDB_CTL))

TIDB_BINLOG_SOURCE: $(SOURCE_DIR)
	$(call fetch_source, $(TIDB_BINLOG_SOURCE), $(GIT_URL_TIDB_BINLOG))

TIKV_IMPORTER_SOURCE: $(SOURCE_DIR)
	$(call fetch_source, $(TIKV_IMPORTER_SOURCE), $(GIT_URL_TIKV_IMPORTER))

$(ETCD_BINARY_SOURCE):
	wget $(ETCD_V_3_3_10_BIN_URL)
	tar -zxf $(ETCD_TARBALL_NAME) -C $(SOURCE_DIR)
	rm -f $(ETCD_TARBALL_NAME)

.PHONY: check
check:
	@echo start check
ifndef TAG
	$(error TAG must be specified)
endif
ifneq ($(shell [ $(BUILD_MODE) != $(BUILD_MODE_DOCKER) ] && [ $(BUILD_MODE) != $(BUILD_MODE_LOCAL) ] && echo $(BUILD_MODE) ),)
	$(error Unknown BUILD_MODE: $(BUILD_MODE))
endif

.PHONY: source source-tidb source-toolkit
source: source-tidb source-tidb-toolkit
source-tidb: TIDB_SOURCE TIKV_SOURCE PD_SOURCE TIDB_CTL_SOURCE TIDB_BINLOG_SOURCE
source-tidb-toolkit: PD_SOURCE TIDB_LIGHTNING_SOURCE TIDB_TOOLS_SOURCE TIKV_IMPORTER_SOURCE

.PHONY: binary
binary: binary-tidb binary-tidb-toolkit
binary-tidb: source-tidb build-prepare $(ARTIFACT_BINARY_TIDB)
binary-tidb-toolkit: source-tidb-toolkit build-prepare $(ARTIFACT_BINARY_TOOLKIT)

$(ARTIFACT_DIR):
	mkdir -p $(ARTIFACT_DIR)

$(ARTIFACT_BINARY_TIDB): $(ETCD_BINARY_SOURCE)
# checkout and update source code here
ifdef TAG
	$(call update_source_tag, $(TIDB_SOURCE),$(GIT_URL_TIDB), $(TAG))
	$(call update_source_tag, $(TIKV_SOURCE),$(GIT_URL_TIKV), $(TAG))
	$(call update_source_tag, $(PD_SOURCE),$(GIT_URL_PD), $(TAG))
	# always build tidb-ctl at master branch
	$(call update_source_branch, $(TIDB_CTL_SOURCE),$(GIT_URL_TIDB_CTL), master)
	$(call update_source_tag, $(TIDB_BINLOG_SOURCE),$(GIT_URL_TIDB_BINLOG), $(TAG))
endif
	mkdir -p $(ARTIFACT_BINARY_TIDB)
ifeq ($(BUILD_MODE),$(BUILD_MODE_DOCKER))
	docker run \
		-v $(realpath $(TIDB_SOURCE)):/build/tidb \
		-v $(realpath $(TIKV_SOURCE)):/build/tikv \
		-v $(realpath $(PD_SOURCE)):/build/pd \
		-v $(realpath $(TIDB_BINLOG_SOURCE)):/build/tidb-binlog \
		-v $(realpath $(TIDB_CTL_SOURCE)):/build/tidb-ctl \
		-v $(CURDIR)/scripts/build-tidb.sh:/build-tidb.sh \
		-v $(CURDIR)/${ARTIFACT_BINARY_TIDB}:/out \
		-e SOURCE_DIR=/build \
		-e TARGET_DIR=/out \
		$(BUILDER_IMAGE_BINARY) /build-tidb.sh
else ifeq ($(BUILD_MODE),$(BUILD_MODE_LOCAL))
	SOURCE_DIR=$(realpath $(SOURCE_DIR)) TARGET_DIR=$(CURDIR)/$(ARTIFACT_BINARY_TIDB) scripts/build-tidb.sh
endif
	cp $(ETCD_BINARY_SOURCE)/etcdctl $(ARTIFACT_BINARY_TIDB)

$(ARTIFACT_BINARY_TOOLKIT):
# checkout and update source code here
ifdef TAG
	$(call update_source_tag, $(PD_SOURCE),$(GIT_URL_PD), $(TAG))
	$(call update_source_tag, $(TIDB_LIGHTNING_SOURCE),$(GIT_URL_TIDB_LIGHTNING), $(TAG))
	$(call update_source_tag, $(TIDB_TOOLS_SOURCE),$(GIT_URL_TIDB_TOOLS), $(TAG))
	$(call update_source_tag, $(TIKV_IMPORTER_SOURCE),$(GIT_URL_TIKV_IMPORTER), $(TAG))
endif
ifeq ($(BUILD_MODE),$(BUILD_MODE_DOCKER))
	docker run \
		-v $(realpath $(PD_SOURCE)):/build/pd \
		-v $(realpath $(TIDB_LIGHTNING_SOURCE)):/build/tidb-lightning \
		-v $(realpath $(TIDB_TOOLS_SOURCE)):/build/tidb-tools \
		-v $(realpath $(TIKV_IMPORTER_SOURCE)):/build/importer \
		-v $(CURDIR)/scripts/build-toolkit.sh:/build-toolkit.sh \
		-v $(CURDIR)/${ARTIFACT_BINARY_TOOLKIT}:/out \
		-e SOURCE_DIR=/build \
        -e TARGET_DIR=/out \
		$(BUILDER_IMAGE_BINARY) /build-toolkit.sh
else ifeq ($(BUILD_MODE),$(BUILD_MODE_LOCAL))
	mkdir -p $(ARTIFACT_BINARY_TOOLKIT)
	SOURCE_DIR=$(realpath $(SOURCE_DIR)) TARGET_DIR=$(CURDIR)/$(ARTIFACT_BINARY_TOOLKIT) scripts/build-toolkit.sh
endif

$(ARTIFACT_DOCKER): $(ARTIFACT_BINARY) $(ARTIFACT_DIR)
	mkdir -p $(ARTIFACT_DIR)
	bash ./scripts/gen-image-dockerfile.sh $(VERSION) | docker build -t ${TIDB_DOCKER_IMAGE_TAG} -f - .
	docker save ${TIDB_DOCKER_IMAGE_TAG} | gzip > ${ARTIFACT_DOCKER}

.PHONY: build-prepare docker docker-builder
build-prepare: check $(builder-prepare)
docker: build-prepare source-tidb $(ARTIFACT_DOCKER)
docker-builder:
ifeq ($(shell docker images -q $(BUILDER_IMAGE_BINARY)),)
	bash ./scripts/gen-builder.sh $(shell cat $(TIKV_SOURCE)/rust-toolchain) $(ARCH) | docker build -t $(BUILDER_IMAGE_BINARY) -f - .
endif

.PHONY: rpm rpm-tidb rpm-tidb-toolkit
rpm-builder:
ifeq ($(shell docker images -q $(BUILDER_IMAGE_RPM)),)
	docker build -t $(BUILDER_IMAGE_RPM) -f etc/dockerfile/builder-rpm.dockerfile .
endif

rpm: rpm-tidb rpm-tidb-toolkit

rpm-tidb-package:
	mkdir -p rpmbuild/SOURCES rpmbuild/SPECS rpmbuild/BUILD rpmbuild/SOURCES/bin rpmbuild/SOURCES/service \
	rpmbuild/SOURCES/config/tidb rpmbuild/SOURCES/config/tikv rpmbuild/SOURCES/config/pd \
	rpmbuild/SOURCES/config/arbiter rpmbuild/SOURCES/config/drainer rpmbuild/SOURCES/config/pump \
	rpmbuild/SOURCES/config/reparo
	cp $(CURDIR)/${ARTIFACT_BINARY_TIDB}/* rpmbuild/SOURCES/bin
	cp $(CURDIR)/etc/service/* rpmbuild/SOURCES/service
	cp $(TIDB_SOURCE)/LICENSE rpmbuild/BUILD/LICENSE
	cp $(TIDB_SOURCE)/README.md rpmbuild/BUILD/README.md
	cp $(TIDB_SOURCE)/config/config.toml.example rpmbuild/SOURCES/config/tidb/config.toml
	cp $(TIKV_SOURCE)/etc/config-template.toml rpmbuild/SOURCES/config/tikv/config.toml
	cp $(PD_SOURCE)/conf/config.toml rpmbuild/SOURCES/config/pd/config.toml
	cp $(TIDB_BINLOG_SOURCE)/cmd/arbiter/arbiter.toml rpmbuild/SOURCES/config/arbiter/arbiter.toml
	cp $(TIDB_BINLOG_SOURCE)/cmd/drainer/drainer.toml rpmbuild/SOURCES/config/drainer/drainer.toml
	cp $(TIDB_BINLOG_SOURCE)/cmd/pump/pump.toml rpmbuild/SOURCES/config/pump/pump.toml
	cp $(TIDB_BINLOG_SOURCE)/cmd/reparo/reparo.toml rpmbuild/SOURCES/config/reparo/reparo.toml
	bash scripts/gen-tidb-rpm-spec.sh $(VERSION) > rpmbuild/SPECS/tidb.spec

rpm-tidb: build-prepare source-tidb $(rpm-builder-prepare) $(ARTIFACT_BINARY_TIDB) $(ARTIFACT_DIR) rpm-tidb-package
ifeq ($(BUILD_MODE),$(BUILD_MODE_DOCKER))
	docker run \
		--rm \
		-v $(CURDIR)/rpmbuild:/root/rpmbuild \
		$(BUILDER_IMAGE_RPM) rpmbuild -bb /root/rpmbuild/SPECS/tidb.spec
else ifeq ($(BUILD_MODE),$(BUILD_MODE_LOCAL))
	rpmbuild --define "_topdir $(CURDIR)/rpmbuild" -bb rpmbuild/SPECS/tidb.spec
endif
	cp rpmbuild/RPMS/$(I_ARCH)/*.rpm $(ARTIFACT_DIR)
	rm -rf rpmbuild

rpm-toolkit-package:
	mkdir -p rpmbuild/SOURCES rpmbuild/SPECS rpmbuild/BUILD rpmbuild/SOURCES/bin rpmbuild/SOURCES/service \
	rpmbuild/SOURCES/config/sync_diff_inspector rpmbuild/SOURCES/tidb-lightning/tikv
	cp $(CURDIR)/${ARTIFACT_BINARY_TOOLKIT}/* rpmbuild/SOURCES/bin
	cp $(CURDIR)/etc/service/tidb-lightning.service rpmbuild/SOURCES/service
	cp $(CURDIR)/etc/service/tikv-importer.service rpmbuild/SOURCES/service
	cp $(lightning_path)/LICENSE rpmbuild/BUILD/LICENSE
	cp $(importer_path)/etc/tikv-importer.toml rpmbuild/SOURCES/config/tikv-importer/tikv-importer.toml
	cp $(lightning_path)/tidb-lightning.toml rpmbuild/SOURCES/config/tidb-lightning/tidb-lightning.toml
	cp $(tools_path)/sync_diff_inspector/config.toml rpmbuild/SOURCES/config/sync_diff_inspector/config.toml
	cp $(tools_path)/sync_diff_inspector/config_sharding.toml rpmbuild/SOURCES/config/sync_diff_inspector/config_sharding.toml
	bash scripts/gen-tidb-toolkit-rpm-spec.sh $(VERSION) > rpmbuild/SPECS/tidb-toolkit.spec

rpm-tidb-toolkit: build-prepare  $(rpm-builder-prepare) source-tidb-toolkit $(ARTIFACT_BINARY_TOOLKIT) $(ARTIFACT_DIR) rpm-toolkit-package
ifeq ($(BUILD_MODE),$(BUILD_MODE_DOCKER))
	docker run \
		--rm \
		-v $(CURDIR)/rpmbuild:/root/rpmbuild \
		$(BUILDER_IMAGE_RPM) rpmbuild -bb /root/rpmbuild/SPECS/tidb-toolkit.spec
else ifeq ($(BUILD_MODE),$(BUILD_MODE_LOCAL))
	rpmbuild --define "_topdir $(CURDIR)/rpmbuild" -bb rpmbuild/SPECS/tidb-toolkit.spec
endif
	cp rpmbuild/RPMS/$(I_ARCH)/*.rpm $(ARTIFACT_DIR)
	rm -rf rpmbuild

$(ARTIFACT_PACKAGE): $(ARTIFACT_BINARY_TIDB) $(ARTIFACT_DIR)
	install -D -m 0755 $(ARTIFACT_BINARY_TIDB)/tidb-server ${ARTIFACT_PACKAGE}/usr/bin/tidb-server
	install -D -m 0755 $(ARTIFACT_BINARY_TIDB)/tikv-server ${ARTIFACT_PACKAGE}/usr/bin/tikv-server
	install -D -m 0755 $(ARTIFACT_BINARY_TIDB)/tikv-ctl ${ARTIFACT_PACKAGE}/usr/bin/tikv-ctl
	install -D -m 0755 $(ARTIFACT_BINARY_TIDB)/pd-server ${ARTIFACT_PACKAGE}/usr/bin/pd-server
	install -D -m 0755 $(ARTIFACT_BINARY_TIDB)/pd-ctl ${ARTIFACT_PACKAGE}/usr/bin/pd-ctl
	install -D -m 0755 $(ARTIFACT_BINARY_TIDB)/pd-recover ${ARTIFACT_PACKAGE}/usr/bin/pd-recover
	install -D -m 0755 $(ARTIFACT_BINARY_TIDB)/arbiter ${ARTIFACT_PACKAGE}/usr/bin/arbiter
	install -D -m 0755 $(ARTIFACT_BINARY_TIDB)/binlogctl ${ARTIFACT_PACKAGE}/usr/bin/binlogctl
	install -D -m 0755 $(ARTIFACT_BINARY_TIDB)/drainer ${ARTIFACT_PACKAGE}/usr/bin/drainer
	install -D -m 0755 $(ARTIFACT_BINARY_TIDB)/etcdctl ${ARTIFACT_PACKAGE}/usr/bin/etcdctl
	install -D -m 0755 $(ARTIFACT_BINARY_TIDB)/pump ${ARTIFACT_PACKAGE}/usr/bin/pump
	install -D -m 0755 $(ARTIFACT_BINARY_TIDB)/reparo ${ARTIFACT_PACKAGE}/usr/bin/reparo
	install -D -m 0755 $(ARTIFACT_BINARY_TIDB)/tidb-ctl ${ARTIFACT_PACKAGE}/usr/bin/tidb-ctl

	install -D -m 0644 $(TIDB_SOURCE)/config/config.toml.example ${ARTIFACT_PACKAGE}/etc/tidb/config.toml
	install -D -m 0644 $(TIKV_SOURCE)/etc/config-template.toml ${ARTIFACT_PACKAGE}/etc/tikv/config.toml
	install -D -m 0644 $(PD_SOURCE)/conf/config.toml ${ARTIFACT_PACKAGE}/etc/pd/config.toml
	install -D -m 0644 $(TIDB_BINLOG_SOURCE)/cmd/arbiter/arbiter.toml ${ARTIFACT_PACKAGE}/etc/arbiter/arbiter.toml
	install -D -m 0644 $(TIDB_BINLOG_SOURCE)/cmd/drainer/drainer.toml ${ARTIFACT_PACKAGE}/etc/arbiter/arbiter.toml
	install -D -m 0644 $(TIDB_BINLOG_SOURCE)/cmd/pump/pump.toml ${ARTIFACT_PACKAGE}/etc/pump/pump.toml
	install -D -m 0644 $(TIDB_BINLOG_SOURCE)/cmd/reparo/reparo.toml ${ARTIFACT_PACKAGE}/etc/reparo/reparo.toml

	install -D -m 0644 etc/service/tidb-server.service ${ARTIFACT_PACKAGE}/usr/lib/systemd/system/tidb-server.service
	install -D -m 0644 etc/service/tikv-server.service ${ARTIFACT_PACKAGE}/usr/lib/systemd/system/tikv-server.service
	install -D -m 0644 etc/service/pd-server.service ${ARTIFACT_PACKAGE}/usr/lib/systemd/system/pd-server.service
	install -D -m 0644 etc/service/arbiter.service ${ARTIFACT_PACKAGE}/usr/lib/systemd/system/arbiter.service
	install -D -m 0644 etc/service/drainer.service ${ARTIFACT_PACKAGE}/usr/lib/systemd/system/drainer.service
	install -D -m 0644 etc/service/pump.service ${ARTIFACT_PACKAGE}/usr/lib/systemd/system/pump.service
	install -D -m 0644 etc/service/reparo.service ${ARTIFACT_PACKAGE}/usr/lib/systemd/system/reparo.service

	mkdir -p ${ARTIFACT_PACKAGE}/var/lib/tikv ${ARTIFACT_PACKAGE}/var/lib/tikv ${ARTIFACT_PACKAGE}/var/lib/pd \
		${ARTIFACT_PACKAGE}/var/lib/arbiter ${ARTIFACT_PACKAGE}/var/lib/drainer ${ARTIFACT_PACKAGE}/var/lib/pump \
		${ARTIFACT_PACKAGE}/var/lib/reparo

.PHONY: deb deb-builder deb-tidb deb-toolkit
deb-builder:
ifeq ($(shell docker images -q $(BUILDER_IMAGE_DEB)),)
	docker build -t $(BUILDER_IMAGE_DEB) -f etc/dockerfile/builder-deb.dockerfile scripts
endif

deb: deb-tidb deb-toolkit
deb-tidb: build-prepare $(deb-builder-prepare) $(ARTIFACT_PACKAGE)
	bash scripts/gen-tidb-deb-control.sh $(VERSION) | install -D /dev/stdin ${ARTIFACT_PACKAGE}/DEBIAN/control
	install -D -m 0755 etc/deb/tidb/preinst ${ARTIFACT_PACKAGE}/DEBIAN/preinst
	install -D -m 0755 etc/deb/tidb/postinst ${ARTIFACT_PACKAGE}/DEBIAN/postinst
	docker run \
		--rm \
		-v $(CURDIR)/${BUILD_DIR}:/build \
		$(BUILDER_IMAGE_DEB) fakeroot dpkg-deb --build ${ARTIFACT_PACKAGE} /build/dist
	rm -rf ${ARTIFACT_PACKAGE}

deb-toolkit: build-prepare deb-builder $(ARTIFACT_BINARY_TOOLKIT)  $(ARTIFACT_DIR)
	install -D -m 0755 $(ARTIFACT_BINARY_TOOLKIT)/tidb-lightning ${ARTIFACT_PACKAGE}/usr/bin/tidb-lightning
	install -D -m 0755 $(ARTIFACT_BINARY_TOOLKIT)/tidb-lightning-ctl ${ARTIFACT_PACKAGE}/usr/bin/tidb-lightning-ctl
	install -D -m 0755 $(ARTIFACT_BINARY_TOOLKIT)/tikv-importer ${ARTIFACT_PACKAGE}/usr/bin/tikv-importer
	install -D -m 0755 $(ARTIFACT_BINARY_TOOLKIT)/pd-tso-bench ${ARTIFACT_PACKAGE}/usr/bin/pd-tso-bench
	install -D -m 0755 $(ARTIFACT_BINARY_TOOLKIT)/sync_diff_inspector ${ARTIFACT_PACKAGE}/usr/bin/sync_diff_inspector

	install -D -m 0644 $(TIKV_IMPORTER_SOURCE)/etc/tikv-importer.toml ${ARTIFACT_PACKAGE}/etc/tikv-importer/tikv-importer.toml

	install -D -m 0644 $(TIDB_LIGHTNING_SOURCE)/tidb-lightning.toml ${ARTIFACT_PACKAGE}/etc/tidb-lightning/tidb-lightning.toml
	install -D -m 0644 $(TIDB_TOOLS_SOURCE)/sync_diff_inspector/config_sharding.toml ${ARTIFACT_PACKAGE}/etc/sync_diff_inspector/config_sharding.toml
	install -D -m 0644 $(TIDB_TOOLS_SOURCE)/sync_diff_inspector/config.toml ${ARTIFACT_PACKAGE}/etc/sync_diff_inspector/config.toml
	install -D -m 0644 etc/service/tidb-lightning.service ${ARTIFACT_PACKAGE}/usr/lib/systemd/system/tidb-lightning.service
	install -D -m 0644 etc/service/tikv-importer.service ${ARTIFACT_PACKAGE}/usr/lib/systemd/system/tikv-importer.service

	mkdir -p ${ARTIFACT_PACKAGE}/var/lib/tidb-lightning ${ARTIFACT_PACKAGE}/var/lib/tikv-importer \
		${ARTIFACT_PACKAGE}/var/lib/sync_diff_inspector

	bash scripts/gen-tidb-toolkit-deb-control.sh $(VERSION) | install -D /dev/stdin ${ARTIFACT_PACKAGE}/DEBIAN/control
	install -D -m 0755 etc/deb/tidb-toolkit/preinst ${ARTIFACT_PACKAGE}/DEBIAN/preinst
	install -D -m 0755 etc/deb/tidb-toolkit/preinst ${ARTIFACT_PACKAGE}/DEBIAN/postinst
	docker run \
		--rm \
		-v $(CURDIR)/${BUILD_DIR}:/build \
		$(BUILDER_IMAGE_DEB) fakeroot dpkg-deb --build ${ARTIFACT_PACKAGE} /build/dist
	rm -rf ${ARTIFACT_PACKAGE}

.PHONY: clean-dist clean-bin clean
clean-dist:
	rm -rf build/dist

clean-bin:
	rm -rf $(ARTIFACT_BINARY)

clean:
	rm -rf build
