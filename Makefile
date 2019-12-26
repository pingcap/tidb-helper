ifdef TAG
	VERSION = $(subst v,,$(TAG))
endif

PROJECT_TIDB=tidb
PROJECT_TIKV=tikv
PROJECT_PD=pd
PROJECT_TIDB_LIGHTNING=tidb-lightning
PROJECT_TIDB_TOOLS=tidb-tools

ORG_PINGCAP=pingcap
ORG_TIKV=tikv

GIT_REPO_BASE_URL=https://github.com
GIT_POSTFIX=.git
GIT_URL_TIDB=$(GIT_REPO_BASE_URL)/$(ORG_PINGCAP)/$(PROJECT_TIDB)$(GIT_POSTFIX)
GIT_URL_TIKV=$(GIT_REPO_BASE_URL)/$(ORG_TIKV)/$(PROJECT_TIKV)$(GIT_POSTFIX)
GIT_URL_PD=$(GIT_REPO_BASE_URL)/$(ORG_PINGCAP)/$(PROJECT_PD)$(GIT_POSTFIX)
GIT_URL_TIDB_LIGHTNING=$(GIT_REPO_BASE_URL)/$(ORG_PINGCAP)/$(PROJECT_TIDB_LIGHTNING)$(GIT_POSTFIX)
GIT_URL_TIDB_TOOLS=$(GIT_REPO_BASE_URL)/$(ORG_PINGCAP)/$(PROJECT_TIDB_TOOLS)$(GIT_POSTFIX)

BUILD_DIR=build
SOURCE_DIR=$(BUILD_DIR)/src
TIDB_SOURCE=$(SOURCE_DIR)/$(PROJECT_TIDB)
TIKV_SOURCE=$(SOURCE_DIR)/$(PROJECT_TIKV)
PD_SOURCE=$(SOURCE_DIR)/$(PROJECT_PD)
TIDB_LIGHTNING_SOURCE=$(SOURCE_DIR)/$(PROJECT_TIDB_LIGHTNING)
TIDB_TOOLS_SOURCE=$(SOURCE_DIR)/$(PROJECT_TIDB_TOOLS)
BINARY_DIR=$(BUILD_DIR)/bin
ARTIFACT_BINARY=$(BINARY_DIR)/$(VERSION)
ARTIFACT_DIR=$(BUILD_DIR)/dist
TIDB_DOCKER_IMAGE_NAME=tidb-docker
TIDB_DOCKER_IMAGE_TAG=$(ORG_PINGCAP)/$(TIDB_DOCKER_IMAGE_NAME):$(VERSION)
ARTIFACT_DOCKER=${ARTIFACT_DIR}/$(TIDB_DOCKER_IMAGE_NAME)-$(VERSION).tar.gz
ARTIFACT_PACKAGE=$(ARTIFACT_DIR)/tidb-pkg
BUILDER_PREFIX=tidb-builder
BUILDER_IMAGE_BINARY=$(ORG_PINGCAP)/$(BUILDER_PREFIX)-binary
BUILDER_IMAGE_RPM=$(ORG_PINGCAP)/$(BUILDER_PREFIX)-rpm
BUILDER_IMAGE_DEB=$(ORG_PINGCAP)/$(BUILDER_PREFIX)-deb

define fetch_source
	@if [ ! -d $(1)/.git ]; then\
		mkdir -p $(1); \
		git clone $(2) $(1); \
	fi
endef

define update_source_tag
	cd $(1) && git fetch $(2) $(3) && git checkout $(3)
endef

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

.PHONY: TIDB_SOURCE TIKV_SOURCE PD_SOURCE TIDB_LIGHTNING_SOURCE TIDB_TOOLS_SOURCE
# don't use directory so we can force update the projects each time.
TIDB_SOURCE:
	$(call fetch_source, $(TIDB_SOURCE),$(GIT_URL_TIDB))

TIKV_SOURCE:
	$(call fetch_source, $(TIKV_SOURCE),$(GIT_URL_TIKV))

PD_SOURCE:
	$(call fetch_source, $(PD_SOURCE),$(GIT_URL_PD))

TIDB_LIGHTNING_SOURCE:
	$(call fetch_source, $(TIDB_LIGHTNING_SOURCE), $(GIT_URL_TIDB_LIGHTNING))

TIDB_TOOLS_SOURCE:
	$(call fetch_source, $(TIDB_TOOLS_SOURCE), $(GIT_URL_TIDB_TOOLS))

.PHONY: check
check:
ifndef TAG
	$(error TAG must be specified)
endif

.PHONY: source source-tidb source-toolkit
source: source-tidb source-tidb-toolkit
source-tidb: TIDB_SOURCE TIKV_SOURCE PD_SOURCE
source-tidb-toolkit: TIDB_LIGHTNING_SOURCE TIDB_TOOLS_SOURCE

.PHONY: binary
binary: build-prepare $(ARTIFACT_BINARY)

$(ARTIFACT_DIR):
	mkdir -p $(ARTIFACT_DIR)

$(ARTIFACT_BINARY):
# checkout and update source code here
ifdef TAG
	$(call update_source_tag, $(TIDB_SOURCE),$(GIT_URL_TIDB), $(TAG))
	$(call update_source_tag, $(TIKV_SOURCE),$(GIT_URL_TIKV), $(TAG))
	$(call update_source_tag, $(PD_SOURCE),$(GIT_URL_PD), $(TAG))
	$(call update_source_tag, $(TIDB_LIGHTNING_SOURCE),$(GIT_URL_TIDB_LIGHTNING), $(TAG))
	$(call update_source_tag, $(TIDB_TOOLS_SOURCE),$(GIT_URL_TIDB_TOOLS), $(TAG))
endif
	docker run \
		-v $(realpath $(TIDB_SOURCE)):/build/tidb \
		-v $(realpath $(TIKV_SOURCE)):/build/tikv \
		-v $(realpath $(PD_SOURCE)):/build/pd \
		-v $(realpath $(TIDB_LIGHTNING_SOURCE)):/build/tidb-lightning \
		-v $(realpath $(TIDB_TOOLS_SOURCE)):/build/tidb-tools \
		-v $(CURDIR)/scripts/build.sh:/build.sh \
		-v $(CURDIR)/${ARTIFACT_BINARY}:/out \
		$(BUILDER_IMAGE_BINARY) /build.sh

$(ARTIFACT_DOCKER): $(ARTIFACT_BINARY) $(ARTIFACT_DIR)
	mkdir -p $(ARTIFACT_DIR)
	bash ./scripts/gen-image-dockerfile.sh $(VERSION) | docker build -t ${TIDB_DOCKER_IMAGE_TAG} -f - .
	docker save ${TIDB_DOCKER_IMAGE_TAG} | gzip > ${ARTIFACT_DOCKER}

.PHONY: build-prepare docker docker-builder
build-prepare: check source docker-builder
docker: build-prepare $(ARTIFACT_DOCKER)

docker-builder:
ifeq ($(shell docker images -q $(BUILDER_IMAGE_BINARY)),)
	bash ./scripts/gen-builder.sh $(shell cat $(TIKV_SOURCE)/rust-toolchain) | docker build -t $(BUILDER_IMAGE_BINARY) -f - .
endif

.PHONY: rpm rpm-tidb rpm-tidb-toolkit
rpm-builder:
ifeq ($(shell docker images -q $(BUILDER_IMAGE_RPM)),)
	docker build -t $(BUILDER_IMAGE_RPM) -f etc/dockerfile/builder-rpm.dockerfile .
endif

rpm: build-prepare rpm-builder rpm-tidb rpm-tidb-toolkit
rpm-tidb: $(ARTIFACT_BINARY) $(ARTIFACT_DIR)
	bash scripts/gen-tidb-rpm-spec.sh $(VERSION) > ${ARTIFACT_DIR}/rpm-spec
	$(eval tidb_path = $(realpath $(TIDB_SOURCE)))
	$(eval tikv_path = $(realpath $(TIKV_SOURCE)))
	$(eval pd_path = $(realpath $(PD_SOURCE)))
	docker run \
		--rm \
		-v $(CURDIR)/${ARTIFACT_BINARY}:/root/rpmbuild/SOURCES/bin \
		-v $(CURDIR)/etc/service:/root/rpmbuild/SOURCES/service \
		-v $(tidb_path)/config/config.toml.example:/root/rpmbuild/SOURCES/config/tidb/config.toml \
		-v $(tikv_path)/etc/config-template.toml:/root/rpmbuild/SOURCES/config/tikv/config.toml \
		-v $(pd_path)/conf/config.toml:/root/rpmbuild/SOURCES/config/pd/config.toml \
		-v $(tidb_path)/LICENSE:/root/rpmbuild/BUILD/LICENSE \
		-v $(tidb_path)/README.md:/root/rpmbuild/BUILD/README.md \
		-v $(CURDIR)/${ARTIFACT_DIR}/rpm-spec:/root/rpmbuild/SPECS/tidb.spec \
		-v $(CURDIR)/${ARTIFACT_DIR}:/root/rpmbuild/RPMS/x86_64/ \
		$(BUILDER_IMAGE_RPM) rpmbuild -bb /root/rpmbuild/SPECS/tidb.spec
	rm ${ARTIFACT_DIR}/rpm-spec

rpm-tidb-toolkit: $(ARTIFACT_BINARY) $(ARTIFACT_DIR)
	bash scripts/gen-tidb-toolkit-rpm-spec.sh $(VERSION) > ${ARTIFACT_DIR}/rpm-spec
	$(eval tikv_path = $(realpath $(TIKV_SOURCE)))
	$(eval pd_path = $(realpath $(PD_SOURCE)))
	$(eval lightning_path=$(realpath $(TIDB_LIGHTNING_SOURCE)))
	$(eval tools_path=$(realpath $(TIDB_TOOLS_SOURCE)))
	docker run \
		--rm \
		-v $(CURDIR)/${ARTIFACT_BINARY}:/root/rpmbuild/SOURCES/bin \
		-v $(CURDIR)/etc/service:/root/rpmbuild/SOURCES/service \
		-v $(tikv_path)/etc/tikv-importer.toml:/root/rpmbuild/SOURCES/config/tikv-importer/tikv-importer.toml \
		-v $(lightning_path)/tidb-lightning.toml:/root/rpmbuild/SOURCES/config/tidb-lightning/tidb-lightning.toml \
		-v $(tools_path)/sync_diff_inspector/config.toml:/root/rpmbuild/SOURCES/config/sync_diff_inspector/config.toml \
		-v $(tools_path)/sync_diff_inspector/config_sharding.toml:/root/rpmbuild/SOURCES/config/sync_diff_inspector/config_sharding.toml \
		-v $(lightning_path)/LICENSE:/root/rpmbuild/BUILD/LICENSE \
		-v $(CURDIR)/${ARTIFACT_DIR}/rpm-spec:/root/rpmbuild/SPECS/tidb-toolkit.spec \
		-v $(CURDIR)/${ARTIFACT_DIR}:/root/rpmbuild/RPMS/x86_64/ \
		$(BUILDER_IMAGE_RPM) rpmbuild -bb /root/rpmbuild/SPECS/tidb-toolkit.spec
	rm ${ARTIFACT_DIR}/rpm-spec

$(ARTIFACT_PACKAGE): $(ARTIFACT_BINARY) $(ARTIFACT_DIR)
	install -D -m 0755 $(ARTIFACT_BINARY)/tidb-server ${ARTIFACT_PACKAGE}/usr/bin/tidb-server
	install -D -m 0755 $(ARTIFACT_BINARY)/tikv-server ${ARTIFACT_PACKAGE}/usr/bin/tikv-server
	install -D -m 0755 $(ARTIFACT_BINARY)/tikv-ctl ${ARTIFACT_PACKAGE}/usr/bin/tikv-ctl
	install -D -m 0755 $(ARTIFACT_BINARY)/pd-server ${ARTIFACT_PACKAGE}/usr/bin/pd-server
	install -D -m 0755 $(ARTIFACT_BINARY)/pd-ctl ${ARTIFACT_PACKAGE}/usr/bin/pd-ctl
	install -D -m 0755 $(ARTIFACT_BINARY)/pd-recover ${ARTIFACT_PACKAGE}/usr/bin/pd-recover
	install -D -m 0644 $(TIDB_SOURCE)/config/config.toml.example ${ARTIFACT_PACKAGE}/etc/tidb/config.toml
	install -D -m 0644 $(TIKV_SOURCE)/etc/config-template.toml ${ARTIFACT_PACKAGE}/etc/tikv/config.toml
	install -D -m 0644 $(PD_SOURCE)/conf/config.toml ${ARTIFACT_PACKAGE}/etc/pd/config.toml
	install -D -m 0644 etc/service/tidb-server.service ${ARTIFACT_PACKAGE}/usr/lib/systemd/system/tidb.service
	install -D -m 0644 etc/service/tikv-server.service ${ARTIFACT_PACKAGE}/usr/lib/systemd/system/tikv.service
	install -D -m 0644 etc/service/pd-server.service ${ARTIFACT_PACKAGE}/usr/lib/systemd/system/pd.service
	mkdir -p ${ARTIFACT_PACKAGE}/var/lib/tikv ${ARTIFACT_PACKAGE}/var/lib/tikv ${ARTIFACT_PACKAGE}/var/lib/pd

.PHONY: deb deb-builder deb-tidb deb-toolkit
deb-builder:
ifeq ($(shell docker images -q $(BUILDER_IMAGE_DEB)),)
	docker build -t $(BUILDER_IMAGE_DEB) -f etc/dockerfile/builder-deb.dockerfile scripts
endif

deb: deb-tidb deb-toolkit
deb-tidb: build-prepare deb-builder $(ARTIFACT_PACKAGE)
	bash scripts/gen-tidb-deb-control.sh $(VERSION) | install -D /dev/stdin ${ARTIFACT_PACKAGE}/DEBIAN/control
	install -D -m 0755 etc/deb/tidb/preinst ${ARTIFACT_PACKAGE}/DEBIAN/preinst
	install -D -m 0755 etc/deb/tidb/postinst ${ARTIFACT_PACKAGE}/DEBIAN/postinst
	docker run \
		--rm \
		-v $(CURDIR)/${BUILD_DIR}:/build \
		$(BUILDER_IMAGE_DEB) fakeroot dpkg-deb --build ${ARTIFACT_PACKAGE} /build/dist
	rm -rf ${ARTIFACT_PACKAGE}

deb-toolkit: build-prepare deb-builder $(ARTIFACT_BINARY) $(ARTIFACT_DIR)
	install -D -m 0755 $(ARTIFACT_BINARY)/tidb-lightning ${ARTIFACT_PACKAGE}/usr/bin/tidb-lightning
	install -D -m 0755 $(ARTIFACT_BINARY)/tidb-lightning-ctl ${ARTIFACT_PACKAGE}/usr/bin/tidb-lightning-ctl
	install -D -m 0755 $(ARTIFACT_BINARY)/tikv-importer ${ARTIFACT_PACKAGE}/usr/bin/tikv-importer
	install -D -m 0755 $(ARTIFACT_BINARY)/pd-tso-bench ${ARTIFACT_PACKAGE}/usr/bin/pd-tso-bench
	install -D -m 0755 $(ARTIFACT_BINARY)/sync_diff_inspector ${ARTIFACT_PACKAGE}/usr/bin/sync_diff_inspector
	install -D -m 0644 $(TIKV_SOURCE)/etc/tikv-importer.toml ${ARTIFACT_PACKAGE}/etc/tikv-importer/tikv-importer.toml
	install -D -m 0644 $(TIDB_LIGHTNING_SOURCE)/tidb-lightning.toml ${ARTIFACT_PACKAGE}/etc/tidb-lightning/tidb-lightning.toml
	install -D -m 0644 $(TIDB_TOOLS_SOURCE)/sync_diff_inspector/config_sharding.toml ${ARTIFACT_PACKAGE}/etc/sync_diff_inspector/config_sharding.toml
	install -D -m 0644 $(TIDB_TOOLS_SOURCE)/sync_diff_inspector/config.toml ${ARTIFACT_PACKAGE}/etc/sync_diff_inspector/config.toml
	install -D -m 0644 etc/service/tidb-lightning.service ${ARTIFACT_PACKAGE}/usr/lib/systemd/system/tidb-lightning.service
	install -D -m 0644 etc/service/tikv-importer.service ${ARTIFACT_PACKAGE}/usr/lib/systemd/system/tikv-importer.service
	mkdir -p ${ARTIFACT_PACKAGE}/var/lib/tidb-lightning ${ARTIFACT_PACKAGE}/var/lib/tikv-importer ${ARTIFACT_PACKAGE}/var/lib/sync_diff_inspector

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
