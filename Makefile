SOURCE_DIR=src
EBIN_DIR=ebin
DOC_DIR=doc
INCLUDE_DIR=include
INCLUDES=$(wildcard $(INCLUDE_DIR)/*.hrl)
SOURCES=$(wildcard $(SOURCE_DIR)/*.erl)
TARGETS=$(patsubst $(SOURCE_DIR)/%.erl, $(EBIN_DIR)/%.beam,$(SOURCES))
ERLC_OPTS=-I $(INCLUDE_DIR) -o $(EBIN_DIR) $(INETS_DEF) -Wall +debug_info # +native -v
DIST_DIR=dist
SIGNING_KEY_ID=F8D7D525
VERSION=HEAD
PACKAGE_NAME=rfc4627_jsonrpc

## The path to httpd.hrl has changed in OTP R14A and newer. Detect the
## change, and supply a compile-time macro definition to allow
## rfc4627_jsonrpc_inets.erl to adapt to the new path.
ifeq ($(shell test R14A \> $$(erl -noshell -eval 'io:format(erlang:system_info(otp_release)), halt().') && echo yes),yes)
INETS_DEF=
else
INETS_DEF=-Dnew_inets
endif

all: $(TARGETS)

$(EBIN_DIR)/%.beam: $(SOURCE_DIR)/%.erl $(INCLUDES)
	erlc $(ERLC_OPTS) $<

clean:
	rm -f ebin/*.beam
	rm -f $(TARGETS)
	rm -rf $(DIST_DIR)
	rm -rf $(DOC_DIR)

dist: all doc/index.html
	mkdir -p $(DIST_DIR)
	cp -r doc ebin include src test Makefile $(DIST_DIR)

distclean: clean
	rm -rf $(DIST_DIR)
	find . -name '*~' -exec rm {} \;

debian-package: clean
	@(cat debian/changelog | head -1 | fgrep -q 'rfc4627-erlang ($(VERSION))') || \
		(echo "No changelog entry for version $(VERSION) exists. Aborting."; false)
	tar -cf debian-package.tar `ls | grep -v _darcs`
	mkdir build
	cd build; tar -xf ../debian-package.tar
	cd build; dpkg-buildpackage -rfakeroot -k$(SIGNING_KEY_ID)
	rm -rf build debian-package.tar

$(DOC_DIR)/index.html: $(DOC_DIR)/overview.edoc
	erl -noshell \
		-eval 'edoc:application(rfc4627, ".", [{overview, "$(DOC_DIR)/overview.edoc"}, {dir, "$(DOC_DIR)"}])' \
		-run init stop
	cp src/doc/JSON-RPC-1-1-WD-20060807.html $(DOC_DIR)

$(DOC_DIR)/overview.edoc: src/doc/overview.edoc.in
	mkdir -p $(DOC_DIR)
	sed -e 's:%%VERSION%%:$(VERSION):g' < $< > $@

test-compile:
	erlc $(ERLC_OPTS) $(wildcard test/*.erl)

test: all test-compile
	erl -pa ebin -noshell -eval 'passed = test_rfc4627:test_all(), c:q().'
