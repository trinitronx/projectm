# debian/source_package_build.bash
# Source: https://wiki.debian.org/BenFinney/software/repack
# Part of the Debian package ‘libjs-zxcvbn’.
#
# Copyright © 2020 James Cuzella <james.cuzella@lyraphase.com>
# Copyright © 2013–2014 Ben Finney <ben+debian@benfinney.id.au>
# This is free software; see the end of this file for license terms.

# Common code for building Debian upstream source package.

working_dir="$(mktemp -d -t)"

exit_sigspecs="ERR EXIT SIGTERM SIGHUP SIGINT SIGQUIT"

ANY_VERSION='(?:[-_]?(\d[\-+\.:\~\da-zA-Z]*))'
ARCHIVE_EXT='(?i)(?:\.(?:tar\.xz|tar\.bz2|tar\.gz|zip|tgz|tbz|txz))'
DEB_EXT='(?:[\+~](debian|dfsg|ds|deb)([\.-])?(\d+)?)' # modified from uscan regex

function cleanup_exit() {
    exit_status=$?
    trap - $exit_sigspecs

    rm -rf "${working_dir}"
    printf "Cleaned up working directory ‘${working_dir}’\n"

    exit $exit_status
}
trap cleanup_exit $exit_sigspecs

sanity_checks() {
    # Sanity checks
    if [ ! -d debian ]; then
        echo "$PROGNAME: cannot find debian/ directory." >&2
        echo "$PROGNAME: Are you in the debianized source tree?" >&2
        echo "$PROGNAME: You may wish to run debmake or dh_make first." >&2
        exit 1
    fi

    if [ ! -x debian/rules ]; then
        echo "$PROGNAME: cannot find debian/rules." >&2
        echo "Are you in the top directory of the old source tree?" >&2
        exit 1
    fi

    if [ ! -f debian/changelog ]; then
        echo "$PROGNAME: cannot find debian/changelog." >&2
        echo "$PROGNAME: Are you in the top directory of the old source tree?" >&2
        exit 1
    fi
}

mustsetvar() {
    if [ "x$2" = x ]; then
	  echo >&2 "$PROGNAME: unable to determine $3"
	  exit 1
    else
	  [ "$REPACK_VERBOSE" -eq 1 ] && echo "$PROGNAME: $3 is $2"
	  eval "$1=\"\$2\""
    fi
}

sanity_checks

# Figure out package info we need
mustsetvar package_name    "$(dpkg-parsechangelog --show-field Source)"  "source package"
mustsetvar release_version "$(dpkg-parsechangelog --show-field Version)" "source version"

# Get epoch and upstream version
# TODO: if we ever need this... implement similar to uupdate
eval $(echo "$release_version" | perl -ne '/^(?:(\d+):)?(.*)/; print "SVERSION=$2\nEPOCH=$1\n";')

release_dfsg_version=$(printf "${release_version}" \
        | sed -e 's/^[[:digit:]]\+://' -e 's/[-][^-]\+$//')
# Strip DEB_EXT like uscan does
non_dfsg_version_base=$(printf "${release_version}" \
        | perl -p -e "s/$DEB_EXT//; " -e 's/^\d+://; ' -e 's/[-][^-]+$//;')

# Now strip all debian family distro specific version strings (following a '~')
upstream_normalized_version_base=$(printf "${non_dfsg_version_base}" \
        | perl -p -e "s/~.*$//; " -e 's/[-][^-]+$//;')

upstream_dirname="${package_name}-${non_dfsg_version_base}"
dfsg_dirname="${package_name}-${release_dfsg_version}"
upstream_tarball_basename="${package_name}_${upstream_version}.orig"
release_dfsg_tarball_basename="${package_name}_${release_dfsg_version}.orig"

downloaded_file="../${package_name}-${upstream_version}.tar.xz"
if [ ! -f "$downloaded_file" ]; then
  if [ "$TRY_HARDER" -eq 1  ]; then
  # Try to be smarter about detection of tarball uscan downloaded
  downloaded_file="$(find ../ -maxdepth 1 -type f -regextype posix-extended \
	-iregex "../${package_name}-${upstream_normalized_version_base}.*\.tar\.(xz|gz|bz2)" -printf "%T@  %p\n" | \
	sort -n -r  | head -n1 | awk '{print $2 }')"
  else
	  echo "ERROR: Could not find pristine source tarball: $downloaded_file" >&2
  fi
fi

function extract_tarball_to_working_dir() {
    # Extract the specified tarball to the program's working directory.
    local tarball="$1"
	local tar_unzip_flag='-J' # default to --xz
	if [[ "$tarball" == *gz ]]; then
		tar_unzip_flag='-z'
	elif [[ "$tarball" == *bz2 ]]; then
		tar_unzip_flag='-j'
	elif [[ "$tarball" == *xz ]]; then
		tar_unzip_flag='-J'
	elif [[ "$tarball" == *lzma ]]; then
		tar_unzip_flag='--lzma'
	elif [[ "$tarball" == *lzop ]]; then
		tar_unzip_flag='--lzop'
	fi
    tar $tar_unzip_flag -xf "${tarball}" --directory "${working_dir}" || {
	    printf "$PROGNAME: can't untar "${tarball}"\n$PROGNAME: aborting..." >&2 && exit 1
	}
}

function archive_working_dirname_to_tarball() {
    # Archive the specified directory, relative to the working directory,
    # to a new tarball of the specified name.
    local source_dirname="$1"
    local tarball="$2"
    GZIP="--best" tar --xz --directory "${working_dir}" -cf "${tarball}" "${source_dirname}"
}


# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# “Software”), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
# 
# The Software is provided “as is”, without warranty of any kind,
# express or implied, including but not limited to the warranties of
# merchantability, fitness for a particular purpose and noninfringement.
# In no event shall the authors or copyright holders be liable for any
# claim, damages or other liability, whether in an action of contract,
# tort or otherwise, arising from, out of or in connection with the
# Software or the use or other dealings in the Software.


# Local variables:
# coding: utf-8
# mode: sh
# End:
# vim: fileencoding=utf-8 filetype=bash :
