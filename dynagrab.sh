#!/bin/sh

run() {
	if [ -n "$DRYRUN" ]
	then
		echo $*
	else	
		echo $*
		$*
	fi
}

annotate() {
	if [ -z "$DRYRUN" ]; then
		return
	else
		echo $*
	fi
}

# copy_link_tree will copy a file to a destination -- but it will also process recursive symlinks
# and copy the link structure to a destination, if the file is symlink.
# example: copy_link_tree /path/to/my/binary /var/tmp/chroot/bin
#          copy_link_tree /path/to/mylib.so /var/tmp/chroot/lib

copy_link_tree() {
	in=$1
	out=$2
	if [ -L $in ]; then
		dest="$(readlink -e $in)"
		# $in is a symlink. I will create the symlink at $out pointing to $dest, then recurse to ensure its destination is copied.
		run ln -sf "${dest##*/}" "$out/${in##*/}"
		copy_link_tree "$dest" "$out"
	else
		# $in is a regular file, copying directly to $out
		run cp "$in" "$out"
	fi
}

# process_ldd_line is a helper function that processes a single line of ldd output.

process_ldd_line() {
	libout=$1
	shift
	# processing ldd line:
	if [ "$1" == "linux-vdso.so.1" ]; then
		annotate "Skipping linux-vdso.so.1"
	elif [ "$2" == "=>" ]; then
		# I need $3 copied
		copy_link_tree "$3" "$libout"
		if [ -L "$1" ]; then
			run ln -sf "${3##*/}" "$libout/${1##*/}"
		fi
	else
		copy_link_tree "$1" $libout
	fi
}

# dynagrab stands for "dynamic library grab" -- it will grab all shared libraries for a
# specified binary and copy them to a destination. Example:
# dynagrab /path/to/bash /var/tmp/chroot

dynagrab() {
	libout=$2/lib
	ldd $1 > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		# not a dynamic executable
		return
	fi
	ldd $1 | while read line; do
		process_ldd_line $libout $line
	done
}

# copy_binary is the function to be called for copying a binary and all associated shared
# libraries to a destination chroot. Example:
# copy_binary /path/to/bash /var/tmp/chroot
# 
# If the binary is a symlink, it will ensure that the symlink is copied, as well as the target(s)
# pointed to by the symlink. So pointing to /sbin/modprobe will copy the modprobe symlink and
# the kmod binary.

copy_binary() {
	copy_link_tree "$1" "$2"/bin
	dynagrab $(readlink -e $1) $2
}

# grab all shared libs required by binary $1 and copy to destination chroot/initramfs root $2:
[ "$2" = "" ] && echo "Please specify a target chroot as a second argument. Exiting" && exit 1
[ ! -e "$1" ] && echo "File to be copied \"$1\" does not exist. Exiting" && exit 1
run install -d $2/bin
run install -d $2/usr
run install -d $2/dev
if true; then
	# everything is in /bin:
	run ln -snf bin $2/sbin
	run ln -snf ../bin $2/usr/bin
	run ln -snf ../bin $2/usr/sbin
else
	# separate /bin, /sbin, /usr/bin, /usr/sbin:
	run install -d $2/sbin
	run install -d $2/usr/bin
	run install -d $2/usr/sbin
fi
run install -d $2/lib
run ln -snf lib $2/lib64
run ln -snf ../lib $2/usr/lib
run ln -snf ../lib $2/usr/lib64

cp /lib/ld-linux* $2/lib

copy_binary $1 $2

run install -d $2/etc
run touch $2/etc/mtab
echo "/lib" > $2/etc/ld.so.conf
run install -d $2/proc
run install -d $2/root
run ldconfig -r $2
run cp -a /lib/udev $2/lib
run rm -rf $2/lib/udev/hwdb.d
#run udevadm hwdb --update --root=$2

if [ -e $2/bin/toybox ]; then
	( cd $2; for i in $(bin/toybox --long); do run ln -sf toybox $i; done )
fi
