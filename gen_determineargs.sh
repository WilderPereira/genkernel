#!/bin/bash
# $Id$

get_KV() {
	if [ "${KERNEL_SOURCES}" = '0' -a -e "${KERNCACHE}" ]
	then
		/bin/tar -xj -C ${TEMP} -f ${KERNCACHE} kerncache.config 
		if [ -e ${TEMP}/kerncache.config ]
		then
			VER=`grep ^VERSION\ \= ${TEMP}/kerncache.config | awk '{ print $3 };'`
			PAT=`grep ^PATCHLEVEL\ \= ${TEMP}/kerncache.config | awk '{ print $3 };'`
			SUB=`grep ^SUBLEVEL\ \= ${TEMP}/kerncache.config | awk '{ print $3 };'`
			EXV=`grep ^EXTRAVERSION\ \= ${TEMP}/kerncache.config | sed -e "s/EXTRAVERSION =//" -e "s/ //g"`
			LOV=`grep ^CONFIG_LOCALVERSION\= ${TEMP}/kerncache.config | sed -e "s/CONFIG_LOCALVERSION=\"\(.*\)\"/\1/"`
			KV=${VER}.${PAT}.${SUB}${EXV}${LOV}
		else
			gen_die "Could not find kerncache.config in the kernel cache! Exiting."
		fi
	else
		# Configure the kernel
		# If BUILD_KERNEL=0 then assume --no-clean, menuconfig is cleared

		if [ ! -f "${BUILD_SRC}"/Makefile ]
		then
			gen_die "Kernel Makefile (${BUILD_SRC}/Makefile) missing.  Maybe re-install the kernel sources."
		fi

		VER=`grep ^VERSION\ \= ${BUILD_SRC}/Makefile | awk '{ print $3 };'`
		PAT=`grep ^PATCHLEVEL\ \= ${BUILD_SRC}/Makefile | awk '{ print $3 };'`
		SUB=`grep ^SUBLEVEL\ \= ${BUILD_SRC}/Makefile | awk '{ print $3 };'`
		EXV=`grep ^EXTRAVERSION\ \= ${BUILD_SRC}/Makefile | sed -e "s/EXTRAVERSION =//" -e "s/ //g" -e 's/\$([a-z]*)//gi'`

		if [ -z "${SUB}" ]
		then
			# Handle O= build directories
			KERNEL_SOURCE_DIR=`grep ^MAKEARGS\ \:\=  ${BUILD_SRC}/Makefile | awk '{ print $4 };'`
			[ -z "${KERNEL_SOURCE_DIR}" ] && gen_die "Deriving \${KERNEL_SOURCE_DIR} failed"
			SUB=`grep ^SUBLEVEL\ \= ${KERNEL_SOURCE_DIR}/Makefile | awk '{ print $3 };'`
			EXV=`grep ^EXTRAVERSION\ \= ${KERNEL_SOURCE_DIR}/Makefile | sed -e "s/EXTRAVERSION =//" -e "s/ //g" -e 's/\$([a-z]*)//gi'`
		fi

		cd ${BUILD_SRC}
		#compile_generic prepare kernel > /dev/null 2>&1
		cd - > /dev/null 2>&1
		[ -f "${BUILD_SRC}/include/linux/version.h" ] && \
			VERSION_SOURCE="${BUILD_SRC}/include/linux/version.h"
		[ -f "${BUILD_SRC}/include/linux/utsrelease.h" ] && \
			VERSION_SOURCE="${BUILD_SRC}/include/linux/utsrelease.h"
		# Handle new-style releases where version.h doesn't have UTS_RELEASE
		if [ -f ${BUILD_SRC}/include/config/kernel.release ]
		then
			UTS_RELEASE=`cat ${BUILD_SRC}/include/config/kernel.release`
			LOV=`echo ${UTS_RELEASE}|sed -e "s/${VER}.${PAT}.${SUB}${EXV}//"`
			KV=${VER}.${PAT}.${SUB}${EXV}${LOV}
		elif [ -n "${VERSION_SOURCE}" ]
		then
			UTS_RELEASE=`grep UTS_RELEASE ${VERSION_SOURCE} | sed -e 's/#define UTS_RELEASE "\(.*\)"/\1/'`
			LOV=`echo ${UTS_RELEASE}|sed -e "s/${VER}.${PAT}.${SUB}${EXV}//"`
			KV=${VER}.${PAT}.${SUB}${EXV}${LOV}
		else
			determine_config_file
			LCV=`grep ^CONFIG_LOCALVERSION= "${KERNEL_CONFIG}" | sed -r -e "s/.*=\"(.*)\"/\1/"`
			KV=${VER}.${PAT}.${SUB}${EXV}${LCV}
		fi
	fi
}

determine_real_args() {
	print_info 4 "Resolving config file, command line, and arch default settings."

	#                               Dest / Config File   Command Line             Arch Default
	#                               ------------------   ------------             ------------
	set_config_with_override STRING LOGFILE              CMD_LOGFILE
        set_config_with_override STRING BUILD_SRC            CMD_BUILD_SRC           "${DEFAULT_KERNEL_SOURCE}"
        set_config_with_override STRING BUILD_DST            CMD_BUILD_DST           "${BUILD_SRC}"
	set_config_with_override STRING KNAME                CMD_KERNNAME             "genkernel"

	set_config_with_override STRING COMPRESS_INITRD      CMD_COMPRESS_INITRD      "$DEFAULT_COMPRESS_INITRD"
	set_config_with_override STRING COMPRESS_INITRD_TYPE CMD_COMPRESS_INITRD_TYPE "$DEFAULT_COMPRESS_INITRD_TYPE"
	set_config_with_override STRING MAKEOPTS             CMD_MAKEOPTS             "$DEFAULT_MAKEOPTS"
	set_config_with_override STRING KERNEL_MAKE          CMD_KERNEL_MAKE          "$DEFAULT_KERNEL_MAKE"
	set_config_with_override STRING UTILS_MAKE           CMD_UTILS_MAKE           "$DEFAULT_UTILS_MAKE"
	set_config_with_override STRING KERNEL_CC            CMD_KERNEL_CC            ""
	set_config_with_override STRING KERNEL_LD            CMD_KERNEL_LD            ""
	set_config_with_override STRING KERNEL_AS            CMD_KERNEL_AS            ""

	set_config_with_override STRING KERNEL_CROSS_COMPILE CMD_KERNEL_CROSS_COMPILE
	set_config_with_override STRING UTILS_CROSS_COMPILE  CMD_UTILS_CROSS_COMPILE
	set_config_with_override STRING BOOTDIR              CMD_BOOTDIR              "/boot"
	set_config_with_override STRING MODPROBEDIR          CMD_MODPROBEDIR          "/etc/modprobe.d"

	set_config_with_override BOOL   SPLASH               CMD_SPLASH
	set_config_with_override BOOL   POSTCLEAR            CMD_POSTCLEAR
	set_config_with_override BOOL   MRPROPER             CMD_MRPROPER
	set_config_with_override BOOL   MENUCONFIG           CMD_MENUCONFIG
	set_config_with_override BOOL   CLEAN                CMD_CLEAN

	set_config_with_override STRING MINKERNPACKAGE       CMD_MINKERNPACKAGE
	set_config_with_override STRING MODULESPACKAGE       CMD_MODULESPACKAGE
	set_config_with_override STRING KERNCACHE            CMD_KERNCACHE
	set_config_with_override BOOL   RAMDISKMODULES       CMD_RAMDISKMODULES        "yes"
	set_config_with_override BOOL   ALLRAMDISKMODULES    CMD_ALLRAMDISKMODULES     "no"
	set_config_with_override STRING INITRAMFS_OVERLAY    CMD_INITRAMFS_OVERLAY
	set_config_with_override BOOL   MOUNTBOOT            CMD_MOUNTBOOT
	set_config_with_override BOOL   BUILD_STATIC         CMD_STATIC
	set_config_with_override BOOL   SAVE_CONFIG          CMD_SAVE_CONFIG
	set_config_with_override BOOL   SYMLINK              CMD_SYMLINK
	set_config_with_override STRING INSTALL_MOD_PATH     CMD_INSTALL_MOD_PATH
	set_config_with_override BOOL   OLDCONFIG            CMD_OLDCONFIG
	set_config_with_override BOOL   LVM                  CMD_LVM
	set_config_with_override BOOL   DMRAID               CMD_DMRAID
	set_config_with_override BOOL   ISCSI                CMD_ISCSI
	set_config_with_override BOOL   BUSYBOX              CMD_BUSYBOX              "yes"
	set_config_with_override BOOL   UNIONFS              CMD_UNIONFS
	set_config_with_override BOOL   NETBOOT              CMD_NETBOOT
	set_config_with_override STRING REAL_ROOT            CMD_REAL_ROOT
	set_config_with_override BOOL   DISKLABEL            CMD_DISKLABEL
	set_config_with_override BOOL   LUKS                 CMD_LUKS
	set_config_with_override BOOL   GPG                  CMD_GPG
	set_config_with_override BOOL   MDADM                CMD_MDADM
	set_config_with_override STRING MDADM_CONFIG         CMD_MDADM_CONFIG
	set_config_with_override BOOL   ZFS                  CMD_ZFS
	set_config_with_override BOOL   BTRFS                CMD_BTRFS                "$(rootfs_type_is btrfs)"
	set_config_with_override BOOL   MULTIPATH            CMD_MULTIPATH
	set_config_with_override BOOL   FIRMWARE             CMD_FIRMWARE
	set_config_with_override STRING FIRMWARE_DST	     CMD_FIRMWARE_DST	      "/lib/firmware"
	set_config_with_override STRING FIRMWARE_SRC         CMD_FIRMWARE_SRC         "$FIRMWARE_DST"
	set_config_with_override STRING FIRMWARE_FILES       CMD_FIRMWARE_FILES
	set_config_with_override BOOL   INTEGRATED_INITRAMFS CMD_INTEGRATED_INITRAMFS
	set_config_with_override BOOL   GENZIMAGE            CMD_GENZIMAGE
	set_config_with_override BOOL   KEYMAP               CMD_KEYMAP               "yes"
	set_config_with_override BOOL   DOKEYMAPAUTO         CMD_DOKEYMAPAUTO
	set_config_with_override STRING BUSYBOX_CONFIG       CMD_BUSYBOX_CONFIG
	set_config_with_override BOOL   INSTALL              CMD_INSTALL              "yes"

	BOOTDIR=`arch_replace "${BOOTDIR}"`
	BOOTDIR=${BOOTDIR%/}    # Remove any trailing slash
	MODPROBEDIR=${MODPROBEDIR%/}    # Remove any trailing slash

	CACHE_DIR=`arch_replace "${CACHE_DIR}"`
	BUSYBOX_BINCACHE=`cache_replace "${BUSYBOX_BINCACHE}"`
	DMRAID_BINCACHE=`cache_replace "${DMRAID_BINCACHE}"`
	ISCSI_BINCACHE=`cache_replace "${ISCSI_BINCACHE}"`
	BLKID_BINCACHE=`cache_replace "${BLKID_BINCACHE}"`
	FUSE_BINCACHE=`cache_replace "${FUSE_BINCACHE}"`
	UNIONFS_FUSE_BINCACHE=`cache_replace "${UNIONFS_FUSE_BINCACHE}"`
	GPG_BINCACHE=`cache_replace "${GPG_BINCACHE}"`

	DEFAULT_KERNEL_CONFIG=`arch_replace "${DEFAULT_KERNEL_CONFIG}"`
	BUSYBOX_CONFIG=`arch_replace "${BUSYBOX_CONFIG}"`
	BUSYBOX_BINCACHE=`arch_replace "${BUSYBOX_BINCACHE}"`
	DMRAID_BINCACHE=`arch_replace "${DMRAID_BINCACHE}"`
	ISCSI_BINCACHE=`arch_replace "${ISCSI_BINCACHE}"`
	BLKID_BINCACHE=`arch_replace "${BLKID_BINCACHE}"`
	FUSE_BINCACHE=`arch_replace "${FUSE_BINCACHE}"`
	UNIONFS_FUSE_BINCACHE=`arch_replace "${UNIONFS_FUSE_BINCACHE}"`
	GPG_BINCACHE=`arch_replace "${GPG_BINCACHE}"`

	if [ -n "${CMD_BOOTLOADER}" ]
	then
		BOOTLOADER="${CMD_BOOTLOADER}"
		if [ "${CMD_BOOTLOADER}" != "${CMD_BOOTLOADER/:/}" ]
		then
			BOOTFS=`echo "${CMD_BOOTLOADER}" | cut -f2- -d:`
			BOOTLOADER=`echo "${CMD_BOOTLOADER}" | cut -f1 -d:`
		fi
	fi

	if [ "${KERNEL_SOURCES}" != "0" ]
	then
		if [ ! -d ${BUILD_SRC} ]
		then
			gen_die "kernel source directory \"${BUILD_SRC}\" was not found!"
		fi
	fi

	if [ -z "${KERNCACHE}" ]
	then
		if [ "${BUILD_SRC}" = '' -a "${NO_KERNEL_SOURCES}" != "1" ]
		then
			gen_die 'No kernel source directory!'
		fi
		if [ ! -e "${BUILD_SRC}" -a "${NO_KERNEL_SOURCES}" != "1" ]
		then
			gen_die 'No kernel source directory!'
		fi
	else
		if [ "${BUILD_SRC}" = '' ]
		then
			gen_die 'Kernel Cache specified but no kernel tree to verify against!'
		fi
	fi

	# Special case:  If --no-clean is specified on the command line,
	# imply --no-mrproper.
	if [ "${CMD_CLEAN}" != '' ]
	then
		if ! isTrue ${CLEAN}
		then
			MRPROPER=0
		fi
	fi

	if [ -n "${MINKERNPACKAGE}" ]
	then
		mkdir -p `dirname ${MINKERNPACKAGE}`
	fi

	if [ -n "${MODULESPACKAGE}" ]
	then
		mkdir -p `dirname ${MODULESPACKAGE}`
	fi

	if [ -n "${KERNCACHE}" ]
	then
		mkdir -p `dirname ${KERNCACHE}`
	fi

	if ! isTrue "${BUILD_RAMDISK}"
	then
		INTEGRATED_INITRAMFS=0
	fi

	get_KV

	set_config_with_override STRING FULLNAME		CMD_FULLNAME		"${KNAME}-${ARCH}-${KV}"
}
