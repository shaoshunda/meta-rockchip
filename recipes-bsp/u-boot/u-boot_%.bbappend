# Copyright (C) 2019, Fuzhou Rockchip Electronics Co., Ltd
# Released under the MIT license (see COPYING.MIT for the terms)

PATCHPATH = "${CURDIR}/u-boot"
inherit auto-patch

PV = "2017.09+git${SRCPV}"

LIC_FILES_CHKSUM = "file://Licenses/README;md5=a2c678cfd4a4d97135585cad908541c6"

inherit freeze-rev

SRCREV = "bd2c27cc923711a23a21fc9ab43e05d8ac7fc142"
SRCREV_rkbin = "ff92009a11fc85379941f109654546087487d530"
SRC_URI = " \
	git://github.com/JeffyCN/mirrors.git;branch=u-boot; \
	git://github.com/JeffyCN/mirrors.git;branch=rkbin;name=rkbin;destsuffix=rkbin; \
"
SRCREV_FORMAT = "default_rkbin"

# Force using python2 for BSP u-boot
DEPENDS += "python-native"
EXTRA_OEMAKE += "PYTHON=nativepython"

# Needed for packing BSP u-boot
DEPENDS += "coreutils-native python-pyelftools-native"

# Make sure we use nativepython
do_configure_prepend() {
	for s in `grep -rIl python ${S}`; do
		sed -i -e '1s|^#!.*python[23]*|#!/usr/bin/env nativepython|' $s
	done
}

# Generate Rockchip style loader binaries
RK_IDBLOCK_IMG = "idblock.img"
RK_LOADER_BIN = "loader.bin"
RK_TRUST_IMG = "trust.img"
UBOOT_BINARY = "uboot.img"

do_compile_append () {
	cd ${B}

	# Prepare needed files
	for d in make.sh scripts configs arch/arm/mach-rockchip; do
		cp -rT ${S}/${d} ${d}
	done

	# Remove unneeded stages from make.sh
	sed -i -e "/^select_tool/d" -e "/^clean/d" -e "/^\t*make/d" make.sh

	# Pack rockchip loader images
	./make.sh ${UBOOT_MACHINE%_defconfig}

	ln -sf *_loader*.bin "${RK_LOADER_BIN}"

	# Generate idblock image
	bbnote "${PN}: Generating ${RK_IDBLOCK_IMG} from ${RK_LOADER_BIN}"
	./tools/boot_merger --unpack "${RK_LOADER_BIN}"

	if [ -f FlashHead ];then
		cat FlashHead FlashData > "${RK_IDBLOCK_IMG}"
	else
		./tools/mkimage -n "${SOC_FAMILY}" -T rksd -d FlashData \
			"${RK_IDBLOCK_IMG}"
	fi

	cat FlashBoot >> "${RK_IDBLOCK_IMG}"
}

do_deploy_append () {
	cd ${B}

	for binary in "${RK_IDBLOCK_IMG}" "${RK_LOADER_BIN}" "${RK_TRUST_IMG}";do
		[ -f "${binary}" ] || continue
		install "${binary}" "${DEPLOYDIR}/${binary}-${PV}"
		ln -sf "${binary}-${PV}" "${DEPLOYDIR}/${binary}"
	done
}
