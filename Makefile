PACKAGE = tar
ORG = amylum

BUILD_DIR = /tmp/$(PACKAGE)-build
RELEASE_DIR = /tmp/$(PACKAGE)-release
RELEASE_FILE = /tmp/$(PACKAGE).tar.gz
PATH_FLAGS = --prefix=/usr --infodir=/tmp/trash
CONF_FLAGS = 
CFLAGS = 

PACKAGE_VERSION = $$(git --git-dir=upstream/.git describe --tags | sed 's/release_//;s/_/./')
PATCH_VERSION = $$(cat version)
VERSION = $(PACKAGE_VERSION)-$(PATCH_VERSION)

.PHONY : default submodule build_container deps manual container deps build version push local

default: submodule container

build_container:
	docker build -t tar-pkg meta

submodule:
	git submodule update --init

manual: submodule build_container
	./meta/launch /bin/bash || true

container: build_container
	./meta/launch

deps:

build: submodule deps
	rm -rf $(BUILD_DIR)
	cp -R upstream $(BUILD_DIR)
	patch -d $(BUILD_DIR) -p1 < patches/tar-0001-fix-build-failure.patch
	cd $(BUILD_DIR) && ./bootstrap
	cd $(BUILD_DIR) && CC=musl-gcc CFLAGS='$(CFLAGS)' FORCE_UNSAFE_CONFIGURE=1 ./configure $(PATH_FLAGS) $(CONF_FLAGS)
	cd $(BUILD_DIR) && make DESTDIR=$(RELEASE_DIR) install
	rm -rf $(RELEASE_DIR)/tmp $(RELEASE_DIR)/usr/lib/charset.alias
	mkdir -p $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)
	cp $(BUILD_DIR)/COPYING $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)/LICENSE
	cd $(RELEASE_DIR) && tar -czvf $(RELEASE_FILE) *

version:
	@echo $$(($(PATCH_VERSION) + 1)) > version

push: version
	git commit -am "$(VERSION)"
	ssh -oStrictHostKeyChecking=no git@github.com &>/dev/null || true
	git tag -f "$(VERSION)"
	git push --tags origin master
	@sleep 3
	targit -a .github -c -f $(ORG)/$(PACKAGE) $(VERSION) $(RELEASE_FILE)
	@sha512sum $(RELEASE_FILE) | cut -d' ' -f1

local: build push

