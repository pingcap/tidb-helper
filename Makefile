PROJECT_TIDB=tidb
PROJECT_TIKV=tikv
PROJECT_PD=pd
ORG_PINGCAP=pingcap
ORG_TIKV=tikv
GIT_REPO_BASE_URL=https://github.com
GIT_URL_TIDB=$(GIT_REPO_BASE_URL)/$(ORG_PINGCAP)/$(PROJECT_TIDB)
GIT_URL_TIKV=$(GIT_REPO_BASE_URL)/$(ORG_TIKV)/$(PROJECT_TIKV)
GIT_URL_PD=$(GIT_REPO_BASE_URL)/$(ORG_PINGCAP)/$(PROJECT_PD)
BUILD_DIR=build
TIDB_SOURCE=$(BUILD_DIR)/$(PROJECT_TIDB)
TIKV_SOURCE=$(BUILD_DIR)/$(PROJECT_TIKV)
PD_SOURCE=$(BUILD_DIR)/$(PROJECT_PD)
ARTIFACT_BINARY=$(BUILD_DIR)/bin/$(TAG)
ARTIFACT_DIR=$(BUILD_DIR)/dist
ARTIFACT_DOCKER=${ARTIFACT_DIR}/tidb-docker-$(TAG).tar.gz
ARTIFACT_PACKAGE=$(ARTIFACT_DIR)/tidb-pkg
ARTIFACT_RPM=${ARTIFACT_DIR}/
DOCKER_IMAGE_NAME=pingcap/tidb:$(TAG)

define fetch_source
	mkdir -p $(1)
	@if [ ! -d $(1)/.git ]; then\
		git clone $(2).git $(1); \
	fi
endef

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# don't use directory so we can force update the projects each time.
$(TIDB_SOURCE):
	$(call fetch_source, $(TIDB_SOURCE),$(GIT_URL_TIDB))

$(TIKV_SOURCE):
	$(call fetch_source, $(TIKV_SOURCE),$(GIT_URL_TIKV))

$(PD_SOURCE):
	$(call fetch_source, $(PD_SOURCE),$(GIT_URL_PD))

.PHONY: check
check:
ifndef TAG
	$(error TAG must be specified)
endif

.PHONY: source
source: $(TIDB_SOURCE) $(TIKV_SOURCE) $(PD_SOURCE)

.PHONY: binary
binary: check $(ARTIFACT_BINARY)

$(ARTIFACT_BINARY): $(ARTIFACT_DOCKER)
	mkdir -p ${ARTIFACT_BINARY}
	docker load -i ${ARTIFACT_DOCKER}
	docker run --rm \
		--entrypoint=/bin/cp \
		-v $(CURDIR)/${ARTIFACT_BINARY}:/out \
		${DOCKER_IMAGE_NAME} \
		/tidb-server /tikv-server /tikv-ctl /pd-server /pd-ctl /pd-recover /out

$(ARTIFACT_DOCKER): $(TIDB_SOURCE) $(TIKV_SOURCE) $(PD_SOURCE)
	mkdir -p $(ARTIFACT_DIR)
	bash ./scripts/gen-builder-dockerfile.sh $(TAG) | docker build -t ${DOCKER_IMAGE_NAME} -f - .
	docker save ${DOCKER_IMAGE_NAME} | gzip > ${ARTIFACT_DOCKER}

.PHONY: docker
docker: check source $(ARTIFACT_DOCKER)

.PHONY: rpm
rpm: check $(ARTIFACT_BINARY)
	bash scripts/gen-rpm-spec.sh $(TAG) > ${ARTIFACT_DIR}/rpm-spec
	docker build -t tidb-rpm-builder:${TAG} -f etc/dockerfile/builder-rpm.dockerfile .
	docker run \
		--rm \
		-v $(CURDIR)/${ARTIFACT_BINARY}:/root/rpmbuild/SOURCES/bin \
		-v $(CURDIR)/etc/service:/root/rpmbuild/SOURCES/service \
		-v $(CURDIR)/build/tidb/config/config.toml.example:/root/rpmbuild/SOURCES/config/tidb/config.toml.example \
		-v $(CURDIR)/build/tikv/etc/config-template.toml:/root/rpmbuild/SOURCES/config/tikv/config.toml.example \
		-v $(CURDIR)/build/pd/conf/config.toml:/root/rpmbuild/SOURCES/config/pd/config.toml.example \
		-v $(CURDIR)/build/tidb/LICENSE:/root/rpmbuild/BUILD/LICENSE \
		-v $(CURDIR)/build/tidb/README.md:/root/rpmbuild/BUILD/README.md \
		-v $(CURDIR)/${ARTIFACT_DIR}/rpm-spec:/root/rpmbuild/SPECS/tidb.spec \
		-v $(CURDIR)/${ARTIFACT_DIR}:/root/rpmbuild/RPMS/x86_64/ \
		tidb-rpm-builder:${TAG} rpmbuild -bb /root/rpmbuild/SPECS/tidb.spec
	rm ${ARTIFACT_DIR}/rpm-spec

$(ARTIFACT_PACKAGE): $(ARTIFACT_BINARY)
	install -D -m 0755 $(ARTIFACT_BINARY)/tidb-server ${ARTIFACT_PACKAGE}/usr/bin/tidb-server
	install -D -m 0755 $(ARTIFACT_BINARY)/tikv-server ${ARTIFACT_PACKAGE}/usr/bin/tikv-server
	install -D -m 0755 $(ARTIFACT_BINARY)/tikv-ctl ${ARTIFACT_PACKAGE}/usr/bin/tikv-ctl
	install -D -m 0755 $(ARTIFACT_BINARY)/pd-server ${ARTIFACT_PACKAGE}/usr/bin/pd-server
	install -D -m 0755 $(ARTIFACT_BINARY)/pd-ctl ${ARTIFACT_PACKAGE}/usr/bin/pd-ctl
	install -D -m 0755 $(ARTIFACT_BINARY)/pd-recover ${ARTIFACT_PACKAGE}/usr/bin/pd-recover
	install -D -m 0644 build/tidb/config/config.toml.example ${ARTIFACT_PACKAGE}/etc/tidb/config.toml.example
	install -D -m 0644 build/tikv/etc/config-template.toml ${ARTIFACT_PACKAGE}/etc/tikv/config.toml.example
	install -D -m 0644 build/pd/conf/config.toml ${ARTIFACT_PACKAGE}/etc/pd/config.toml.example
	install -D -m 0644 etc/service/tidb-server.service ${ARTIFACT_PACKAGE}/usr/lib/systemd/system/tidb.service
	install -D -m 0644 etc/service/tikv-server.service ${ARTIFACT_PACKAGE}/usr/lib/systemd/system/tikv.service
	install -D -m 0644 etc/service/pd-server.service ${ARTIFACT_PACKAGE}/usr/lib/systemd/system/pd.service
	mkdir -p ${ARTIFACT_PACKAGE}/var/lib/tikv ${ARTIFACT_PACKAGE}/var/lib/tikv ${ARTIFACT_PACKAGE}/var/lib/pd
.PHONY: deb
deb: check $(ARTIFACT_PACKAGE)
	bash scripts/gen-deb-control.sh $(TAG) | install -D /dev/stdin ${ARTIFACT_PACKAGE}/DEBIAN/control
	install -D -m 0755 etc/deb/preinst ${ARTIFACT_PACKAGE}/DEBIAN/preinst
	install -D -m 0755 etc/deb/preinst ${ARTIFACT_PACKAGE}/DEBIAN/postinst
	docker build -t tidb-deb-builder:${TAG} -f etc/dockerfile/builder-deb.dockerfile scripts
	docker run \
		--rm \
		-v $(CURDIR)/${BUILD_DIR}:/build \
		tidb-deb-builder:${TAG} fakeroot dpkg-deb --build ${ARTIFACT_PACKAGE} /build/dist
	rm -rf ${ARTIFACT_PACKAGE}

.PHONY: clean-dist clean-bin clean
clean-dist:
	rm -rf build/dist

clean-bin:
	rm -rf build/bin

clean:
	rm -rf build
