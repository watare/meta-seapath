# Copyright (C) 2021, RTE (http://www.rte-france.com)
# SPDX-License-Identifier: Apache-2.0

#
# Configuration for classes, modules and variables used in
# the hardening environment.
#

BUILDINFO_FILE ?= "${IMAGE_ROOTFS}${IMAGE_BUILDINFO_FILE}"
IMAGE_BUILDINFO_VARS := "DISTRO DISTRO_VERSION IMAGE_NAME"
KERNELCONFIG_FILE ?= "${DEPLOY_DIR_IMAGE}/config_kernel"