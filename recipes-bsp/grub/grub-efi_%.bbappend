# Copyright (C) 2021, RTE (http://www.rte-france.com)
# SPDX-License-Identifier: Apache-2.0

FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

SRC_URI += " \
    file://0001-probe-Support-probing-for-partition-UUID-with-part-u.patch \
"

SRC_URI_append_class-target += " \
    file://grub-efi.cfg   \
"

do_install_append_class-target() {
    if [ "${UEFI_SB}" != "1" ]; then
        install -D -m 0600 "${WORKDIR}/grub-efi.cfg" "${D}${EFI_FILES_PATH}/grub.cfg"
    fi
    rm -rf ${D}${EFI_BOOT_PATH}/${GRUB_TARGET}-efi
    rm -rf ${D}/usr
}

# Ensure that SELoader is installed when enabled while Secureboot is
# also enabled.
# "grub-efi" actually depends on MOK2Verify protocol being installed by
# SELoader before its execution.
RDEPENDS_${PN}_class-target_append = "${@' seloader' if (d.getVar('UEFI_SELOADER') == '1' and d.getVar('UEFI_SB') == '1') else ''}"

# Remove dependency to grub-bootconf as the configuration is installed
# in grub-efi
RDEPENDS_${PN}_class-target_remove = "virtual/grub-bootconf"

FILES_${PN}_remove = "${libdir}/grub"

FILES_${PN}_append = " ${EFI_FILES_PATH}"

GRUB_BUILDIN += " password_pbkdf2 probe regexp chain"
