###############
##   Param   ##
###############

EXE = change_exe_name_in_makefile.exe

GPB ?= 3.13.0
GPB_IMG ?= namely/protoc

COMPOSE ?= docker-compose
RUN ?= docker run --rm --user $$(id -u):$$(id -g)
PROTOC ?= $(RUN) -v "$$PWD:$$PWD" -w "$$PWD" $(GPB_IMG)
PROTOLOCK ?= $(RUN) -v $$PWD:/protolock -w /protolock nilslice/protolock

PB_FILES = $(patsubst proto/%.proto,proto/%.pb.go,$(wildcard proto/*.proto))
PROTO_LOCK_FILE = proto.lock


###############
##   Help    ##
###############

help:
	@fgrep -h "#HELP:" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/#HELP://'

###############
##  Compile  ##
###############

all: #HELP: compile, lint and generates x_files and grpc files
all: proto lint compile

.PHONY: compile
compile:
	CGO_ENABLED=0 go build -o $(EXE)$(if $(wildcard $(EXE)), || rm $(EXE))

# lint: MAKEFLAGS += -j
lint: #HELP: go fmt + go vet + custom lint
lint: fmt vet

fmt:
	go fmt ./...
vet:
	go vet ./...

test: all
	go test ./...

###############
## Protolock ##
###############

.PHONY: proto
proto: $(PROTO_LOCK_FILE) $(PB_FILES)

proto/%.pb.go:  proto/%.proto
	$(PROTOLOCK) commit
	$(PROTOC) -I=./proto --go_out=plugins=grpc:. proto/$*.proto

proto.lock:
	$(PROTOLOCK) init

###############
##   Docker  ##
###############

.PHONY: prune
prune: #HELP: prune unused images, container, network, volumes
prune:
	docker image prune -f
	docker volume prune -f
	docker system prune -f

.PHONY: build
build: #HELP: lint and compile local files and build docker images from local files
build: all
	$(COMPOSE) -f docker-compose.yml build

.PHONY: pull
pull: #HELP: pull docker images
pull:
	$(COMPOSE) pull --ignore-pull-failures

.PHONY: prod
prod: #HELP: pull docker images and clean start docker-compose
prod:
	$(COMPOSE) config -q
	$(COMPOSE) rm -sf
	$(COMPOSE) up

.PHONY: debug
debug: #HELP: Clean start docker-compose with dev option
debug:
	$(COMPOSE) config -q
	$(COMPOSE) -f docker-compose.yml down --volume
	$(COMPOSE) -f docker-compose.yml -svf
	$(COMPOSE) -f docker-compose.yml up
