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
	if [ -n "$DRYRUN" ]; then
		return
	else
		echo $*
	fi
}

# copy_link_tree will copy a file to a destination -- but it will also process recursive symlinks
# and copy the link structure to a destination, if the file is symlink.

copy_link_tree() {
	libout=$1
	shift
	if [ -L $1 ]; then
		dest="$(readlink -e $1)"
		annotate "$1 is a symlink. I will create the symlink at $libout pointing to $dest, then recurse to ensure its destination is copied."
		run ln -sf "${dest##*/}" "$libout/${1##*/}"
		copy_link_tree "$libout" "$dest"
	else
		annotate "$1 is a regular file, copying directly to $libout"
		run cp "$1" $libout 
	fi
}


process_ldd_line() {
	libout=$1
	shift
	annotate "Processing ldd line: $*"
	if [ "$1" == "linux-vdso.so.1" ]; then
		annotate "Skipping linux-vdso.so.1"
	elif [ "$2" == "=>" ]; then
		annotate "I need $3 copied"
		copy_link_tree "$libout" "$3"
		if [ -L "$1" ]; then
			annotate "I will create a symlink named $1 pointing to $3 here"
			run ln -sf "${3##*/}" "$libout/${1##*/}"
		fi
	else
		copy_link_tree "$1" $libout
	fi
}

# dynagrab copies a binary and all associated shared libraries to a chroot.

dynagrab() {
	out=$2
	libout=$3
	install -d $out
	install -d $libout
	if [ ! -L $1 ]; then
		# normal file - copy it over to $out:
		if [ ! -e $out/${1##*/} ]; then
			run "cp $1 $out"
		else
			echo "# $out/${1##*/} exists, skipping..."
		fi
		echo processing file: $1
		ldd $1 | while read line; do
			process_ldd_line $libout $line
		done
	else
		# symlink - create symlink in $libout:
		linkdest=$(readlink $1)
		if [ ! -L $libout/${1##*/} ];
		then
			run "ln -sf $linkdest $libout/${1##*/}"
		else
			echo "# $libout/${1##*/} exists, skipping..."
		fi
		# recurse on target of original symlink, so we can grab everything:
		recurse_on="${1%/*}/${linkdest}"
		dynagrab $recurse_on $libout $libout 
	fi
}

# grab all shared libs required by binary $1 and copy to destination chroot/initramfs root $2:
[ "$2" = "" ] && echo "Please specify a target chroot as a second argument. Exiting" && exit 1
[ ! -e $2/bin ] && run "install -d $2/bin"
[ ! -e $2/lib ] && run "install -d $2/lib"
dynagrab $(readlink -e $1) $2/bin $2/lib
echo "/lib" > $2/etc/ld.so.conf
cp /lib/ld-linux* $2/lib
install -d $2/etc
install -d $2/proc
install -d $2/root
ln -s lib $2/lib64
ldconfig -r $2
