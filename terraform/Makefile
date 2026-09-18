# Usage: make <target> ENV=dev|uat|prod [SHA=<git-sha>]
#
#   make build                 # compile + zip the Lambda binary (ENV-independent)
#   make init ENV=dev          # terraform init with dev's backend config
#   make plan ENV=dev          # terraform plan against dev's tfvars
#   make apply ENV=dev         # terraform apply against dev's tfvars
#   make destroy ENV=dev       # terraform destroy (asks for confirmation)
#   make fmt                   # terraform fmt -recursive
#   make validate ENV=dev      # terraform validate

SHELL := /bin/bash

ENV  ?= dev
SHA  ?= local
ARTIFACT_BUCKET ?= $(shell grep '^artifact_bucket' tfvars/$(ENV).tfvars | cut -d'"' -f2)
ARTIFACT_KEY    := $(ENV)/$(SHA)/bootstrap.zip
ZIP_PATH        := ../bootstrap.zip

ENVS := dev uat prod
ifneq ($(filter $(ENV),$(ENVS)),$(ENV))
$(error ENV must be one of: $(ENVS) — got "$(ENV)")
endif

.PHONY: build init plan apply destroy fmt validate upload-artifact

build:
	./lambda-zipper/build.sh $(ZIP_PATH)

upload-artifact: build
	aws s3 cp $(ZIP_PATH) s3://$(ARTIFACT_BUCKET)/$(ARTIFACT_KEY)

init:
	terraform init -backend-config=backend/$(ENV).tfbackend -reconfigure

plan: init
	terraform plan \
		-var-file=tfvars/$(ENV).tfvars \
		-var="artifact_key=$(ARTIFACT_KEY)"

apply: init
	terraform apply \
		-var-file=tfvars/$(ENV).tfvars \
		-var="artifact_key=$(ARTIFACT_KEY)" \
		-auto-approve

destroy: init
	terraform destroy \
		-var-file=tfvars/$(ENV).tfvars \
		-var="artifact_key=$(ARTIFACT_KEY)"

fmt:
	terraform fmt -recursive

validate: init
	terraform validate
