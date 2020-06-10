#!/bin/bash

# $Id$

###################################
###	    FUNCTIONS		###
###################################


#############################################################


#-------------------------#
chapter_targets() {       #
#-------------------------#
# $1 is the chapter number. Pad it with 0 to the left to obtain a 2-digit
# number:
  printf -v dir chapter%02d $1

  echo "${tab_}${GREEN}Processing... ${L_arrow}Chapter $1${R_arrow}"

  for file in $dir/* ; do
    # Keep the script file name
    this_script=`basename $file`

    # Some scripts need peculiar actions:
    # - glibc chap 5: ix locales creation when running chapter05 testsuites
    # - Stripping at the end of system build: lfs.xsl does not generate
    #   correct commands if the user does not want to strip, so skip it
    #   in this case
    # - grub config: must be done manually; skip it
    # - handle fstab and .config. Skip kernel if .config not supplied
    case "${this_script}" in
      5*glibc)         [[ "${TEST}" = "3" ]] && \
                       sed -i 's@/usr/lib/locale@/tools/lib/locale@' $file ;;
      *strippingagain) [[ "${STRIP}" = "n" ]] && continue ;;
      8*grub)          (( nb_chaps == 5 )) && continue ;;
      10*grub)         continue ;;
      *fstab)          [[ -z "${FSTAB}" ]] ||
                       [[ ${FSTAB} == $BUILDDIR/sources/fstab ]] ||
                       cp ${FSTAB} $BUILDDIR/sources/fstab ;;
      *kernel)         [[ -z ${CONFIG} ]] && continue
                       [[ ${CONFIG} == $BUILDDIR/sources/kernel-config ]] ||
                       cp ${CONFIG} $BUILDDIR/sources/kernel-config  ;;
    esac

    # Append the name of the script to a list. The name of the
    # list is contained in the variable Makefile_target. We adjust this
    # variable at various points. Note that it is initialized to "SETUP"
    # in the main function, before calling this function for the first time.
    case "${this_script}" in
      *settingenvironment) Makefile_target=LUSER_TGT  ;;
      *changingowner     ) Makefile_target=SUDO_TGT   ;;
      *creatingdirs      ) Makefile_target=CHROOT_TGT ;;
      *bootscripts       ) Makefile_target=BOOT_TGT   ;; # case of sysv    book
      *network           ) Makefile_target=BOOT_TGT   ;; # case of systemd book
    esac
    eval $Makefile_target=\"\$$Makefile_target ${this_script}\"

    # Grab the name of the target
    name=`echo ${this_script} | sed -e 's@[0-9]\{3,4\}-@@' \
                                    -e 's@-pass[0-9]\{1\}@@' \
                                    -e 's@-libstdc++@@'`

    #--------------------------------------------------------------------#
    #         >>>>>>>> START BUILDING A Makefile ENTRY <<<<<<<<          #
    #--------------------------------------------------------------------#
    #
    # Find the name of the tarball and the version of the package
    pkg_tarball=$(sed -n 's/tar -xf \(.*\)/\1/p' $file)
    pkg_version=$(sed -n 's/VERSION=\(.*\)/\1/p' $file)

    # Drop in the name of the target on a new line, and the previous target
    # as a dependency. Also call the echo_message function.
    case $Makefile_target in
      CHROOT_TGT)  CHROOT_wrt_target "${this_script}" "$PREV" "$pkg_version" ;;
      *)            LUSER_wrt_target "${this_script}" "$PREV" "$pkg_version" ;;
    esac

    # If $pkg_tarball isn't empty, we've got a package...
    if [ "$pkg_tarball" != "" ] ; then
      # Touch timestamp file if installed files logs shall be created.
      # But only for the final install chapter
      if [ "${INSTALL_LOG}" = "y" ] && (( 1+nb_chaps <= $1 )) ; then
        CHROOT_wrt_TouchTimestamp
      fi
      # Always initialize the test log file, since the test instructions may
      # be "uncommented" by the user
      case $Makefile_target in
       CHROOT_TGT)  CHROOT_wrt_test_log "${this_script}" "$pkg_version" ;;
       LUSER_TGT )  LUSER_wrt_test_log  "${this_script}" "$pkg_version" ;;
      esac

      # If using optimizations, write the instructions
      case "${OPTIMIZE}$1${nb_chaps}${this_script}${REALSBU}" in
          0* | *binutils-pass1y | 15* | 167* | 177*) ;;
          *kernel) wrt_makeflags "$name" ;; # No CFLAGS for kernel
          *) wrt_optimize "$name" && wrt_makeflags "$name" ;;
      esac
    fi

# Some scriptlet have a special treatment; otherwise standard
    case "${this_script}" in
      *addinguser)
(
cat << EOF
	@if [ -f luser-id ]; then \\
	  function useradd() { true; }; \\
	  function groupadd() { true; }; \\
	  export -f useradd groupadd; \\
	fi; \\
	export LFS=\$(MOUNT_PT) && \\
	\$(CMDSDIR)/`dirname $file`/\$@ >> \$(LOGDIR)/\$@ 2>&1; \\
	\$(PRT_DU) >>logs/\$@
	@chown \$(LUSER):\$(LGROUP) envars
	@chmod -R a+wt $JHALFSDIR
	@chmod a+wt \$(SRCSDIR)
EOF
) >> $MKFILE.tmp
	      ;;
      *settingenvironment)
(
cat << EOF
	@cd && \\
	function source() { true; } && \\
	export -f source && \\
	\$(CMDSDIR)/`dirname $file`/\$@ >> \$(LOGDIR)/\$@ 2>&1 && \\
	sed 's|/mnt/lfs|\$(MOUNT_PT)|' -i .bashrc && \\
	echo source $JHALFSDIR/envars >> .bashrc
	@\$(PRT_DU) >>logs/\$@
EOF
) >> $MKFILE.tmp
	      ;;
      *fstab) if [[ -n "$FSTAB" ]]; then
                CHROOT_wrt_CopyFstab
              else
                CHROOT_wrt_RunAsRoot "$file"
              fi
              ;;

      *) 
         # Insert date and disk usage at the top of the log file, the script
         # run and date and disk usage again at the bottom of the log file.
         case "${Makefile_target}" in
           SETUP_TGT | SUDO_TGT)  wrt_RunAsRoot "$file" "$pkg_version" ;;
           LUSER_TGT)             LUSER_wrt_RunAsUser "$file" "$pkg_version" ;;
           CHROOT_TGT | BOOT_TGT) CHROOT_wrt_RunAsRoot "$file" "$pkg_version" ;;
         esac
	      ;;
    esac

    # Write installed files log and remove the build directory(ies)
    # except if the package build fails.
    if [ "$pkg_tarball" != "" ] ; then
      if [ "${INSTALL_LOG}" = "y" ] && (( 1+nb_chaps <= $1 )) ; then
        CHROOT_wrt_LogNewFiles "$name"
      fi
    fi

    # Include a touch of the target name so make can check
    # if it's already been made.
    wrt_touch
    #
    #--------------------------------------------------------------------#
    #              >>>>>>>> END OF Makefile ENTRY <<<<<<<<               #
    #--------------------------------------------------------------------#

    # Keep the script file name for Makefile dependencies.
    PREV=${this_script}
  done  # end for file in $dir/*
}

# NOT USED -- NOT USED
#----------------------------#
chapter5_Makefiles() {
#----------------------------#
  echo "${tab_}${GREEN}Processing... ${L_arrow}Chapter5     ( LUSER ) ${R_arrow}"

# Initialize the Makefile target: it'll change during chapter
# For vanilla lfs, the "changingowner" script should be run as root. So
# it belongs to the "SUDO" target, with list in the "runasroot" variable.
# For new lfs, changingowner and kernfs are in "runasroot", then the following,
# starting at creatingdirs, are in the "CHROOT" target, in variable "chapter6".
# Makefile_target records the variable, not really the target!
# We use a case statement on that variable, because instructions in the
# Makefile change according to the phase of the build (LUSER, SUDO, CHROOT).
  Makefile_target=chapter5

# Start loop
  for file in chapter05/* ; do
    # Keep the script file name
    this_script=`basename $file`

    # Append each name of the script files to a list that Makefile_target
    # points to. But before that, change Makefile_target at the first script
    # of each target.
    case "${this_script}" in
      *changingowner) Makefile_target=runasroot ;;
      *creatingdirs ) Makefile_target=chapter6  ;; # only run for new lfs
    esac
    eval $Makefile_target=\"\$$Makefile_target ${this_script}\"

    # Grab the name of the target (minus the -pass1 or -pass2 in the case of gcc
    # and binutils in chapter 5)
    name=`echo ${this_script} | sed -e 's@[0-9]\{3\}-@@' \
                                    -e 's@-pass[0-9]\{1\}@@' \
                                    -e 's@-libstdc++@@'`

    #--------------------------------------------------------------------#
    #         >>>>>>>> START BUILDING A Makefile ENTRY <<<<<<<<          #
    #--------------------------------------------------------------------#
    #
    # Find the name of the tarball and the version of the package
    pkg_tarball=$(sed -n 's/tar -xf \(.*\)/\1/p' $file)
    pkg_version=$(sed -n 's/VERSION=\(.*\)/\1/p' $file)

    # Drop in the name of the target on a new line, and the previous target
    # as a dependency. Also call the echo_message function.
    case $Makefile_target in
      chapter6) CHROOT_wrt_target "${this_script}" "$PREV" "$pkg_version" ;;
      *)        LUSER_wrt_target "${this_script}" "$PREV" "$pkg_version" ;;
    esac

    # If $pkg_tarball isn't empty, we've got a package...
    if [ "$pkg_tarball" != "" ] ; then
      # Always initialize the log file, since the test instructions may be
      # "uncommented" by the user
      case $Makefile_target in
       chapter6) CHROOT_wrt_test_log "${this_script}" "$pkg_version" ;;
       *)        LUSER_wrt_test_log "${this_script}" "$pkg_version" ;;
      esac

      # If using optimizations, write the instructions
      case "${OPTIMIZE}${this_script}${REALSBU}" in
          *binutils-pass1y) ;;
          2*) wrt_optimize "$name" && wrt_makeflags "$name" ;;
          *) ;;
      esac
    fi

    # Insert date and disk usage at the top of the log file, the script run
    # and date and disk usage again at the bottom of the log file.
    # The changingowner script must be run as root.
    case "${Makefile_target}" in
      runasroot)  wrt_RunAsRoot "$file" "$pkg_version" ;;
      chapter5)   LUSER_wrt_RunAsUser "$file" "$pkg_version" ;;
      chapter6)   CHROOT_wrt_RunAsRoot "$file" "$pkg_version" ;;
    esac

    # Include a touch of the target name so make can check
    # if it's already been made.
    wrt_touch
    #
    #--------------------------------------------------------------------#
    #              >>>>>>>> END OF Makefile ENTRY <<<<<<<<               #
    #--------------------------------------------------------------------#

    # Keep the script file name for Makefile dependencies.
    PREV=${this_script}
  done  # end for file in chapter05/*
}

# NOT USED -- NOT USED keep for ICA code
#----------------------------#
chapter6_Makefiles() {
#----------------------------#

  # Set envars and scripts for iteration targets
  if [[ -z "$1" ]] ; then
    local N=""
  else
    local N=-build_$1
    local chapter6=""
    mkdir chapter06$N
    cp chapter06/* chapter06$N
    for script in chapter06$N/* ; do
      # Overwrite existing symlinks, files, and dirs
      sed -e 's/ln *-sv/&f/g' \
          -e 's/mv *-v/&f/g' \
          -e 's/mkdir *-v/&p/g' -i ${script}
      # Suppress the mod of "test-installation.pl" because now
      # the library path points to /usr/lib
      if [[ ${script} =~ glibc ]]; then
          sed '/DL=/,/unset DL/d' -i ${script}
      fi
      # Rename the scripts
      mv ${script} ${script}$N
    done
    # Remove Bzip2 binaries before make install (LFS-6.2 compatibility)
    sed -e 's@make install@rm -vf /usr/bin/bz*\n&@' -i chapter06$N/*-bzip2$N
    # Remove openssl-<version> from /usr/share/doc (LFS-9.x), because
    # otherwise the mv command creates an openssl directory.
    sed -e 's@mv -v@rm -rfv /usr/share/doc/openssl-*\n&@' \
        -i chapter06$N/*-openssl$N
  fi

  echo "${tab_}${GREEN}Processing... ${L_arrow}Chapter6$N     ( CHROOT ) ${R_arrow}"

# Initialize the Makefile target. In vanilla lfs, kernfs should be run as root,
# then the others are run in chroot. If in new lfs, we should start in chroot.
# this will be changed later because man-pages is the first script in
# chapter 6. Note that this Makefile_target business is not really needed here
# but we do it to have a similar structure to chapter 5 (we may merge all
# those functions at some point).
  case "$N" in
     -build*) Makefile_target=chapter6   ;;
           *) Makefile_target=runasroot  ;;
  esac

# Start loop
  for file in chapter06$N/* ; do
    # Keep the script file name
    this_script=`basename $file`

    # Skip the "stripping" scripts if the user does not want to strip.
    # Skip also linux-headers in iterative builds.
    case "${this_script}" in
      *stripping*) [[ "${STRIP}" = "n" ]] && continue ;;
      *linux-headers*) [[ -n "$N" ]] && continue ;;
    esac

    # Grab the name of the target.
    name=`echo ${this_script} | sed -e 's@[0-9]\{3\}-@@' -e 's,'$N',,'`

    # Find the tarball corresponding to our script.
    # If it doesn't exist, we skip it in iterations rebuilds (except stripping
    # and revisedchroot, where .a and .la files are removed).
    pkg_tarball=$(sed -n 's/tar -xf \(.*\)/\1/p' $file)
    pkg_version=$(sed -n 's/VERSION=\(.*\)/\1/p' $file)

    if [[ "$pkg_tarball" = "" ]] && [[ -n "$N" ]] ; then
      case "${this_script}" in
        *stripping*|*revised*) ;;
        *)  continue ;;
      esac
    fi

    # Append each name of the script files to a list (this will become
    # the names of the targets in the Makefile)
    # The kernfs script must be run as part of SUDO target.
    case "${this_script}" in
            *creatingdirs) Makefile_target=chapter6 ;;
            *man-pages   ) Makefile_target=chapter6 ;;
    esac
    eval $Makefile_target=\"\$$Makefile_target ${this_script}\"

    #--------------------------------------------------------------------#
    #         >>>>>>>> START BUILDING A Makefile ENTRY <<<<<<<<          #
    #--------------------------------------------------------------------#
    #
    # Drop in the name of the target on a new line, and the previous target
    # as a dependency. Also call the echo_message function.
    # In the mount of kernel filesystems we need to set LFS
    # and not to use chroot.
    case "${Makefile_target}" in
      runasroot)  LUSER_wrt_target  "${this_script}" "$PREV" "$pkg_version" ;;
      *)          CHROOT_wrt_target "${this_script}" "$PREV" "$pkg_version" ;;
    esac

    # If $pkg_tarball isn't empty, we've got a package...
    # Insert instructions for unpacking the package and changing directories
    if [ "$pkg_tarball" != "" ] ; then
      # Touch timestamp file if installed files logs will be created.
      # But only for the firt build when running iterative builds.
      if [ "${INSTALL_LOG}" = "y" ] && [ "x${N}" = "x" ] ; then
        CHROOT_wrt_TouchTimestamp
      fi
      # Always initialize the log file, so that the user may reinstate a
      # commented out test
      CHROOT_wrt_test_log "${this_script}" "$pkg_version"
      # If using optimizations, write the instructions
      [[ "$OPTIMIZE" != "0" ]] &&  wrt_optimize "$name" && wrt_makeflags "$name"
    fi

    # In the mount of kernel filesystems we need to set LFS
    # and not to use chroot.
    case "${Makefile_target}" in
      runasroot)  wrt_RunAsRoot  "$file" "$pkg_version" ;;
      *)          CHROOT_wrt_RunAsRoot "$file" "$pkg_version" ;;
    esac

    # Write installed files log and remove the build directory(ies)
    # except if the package build fails.
    if [ "$pkg_tarball" != "" ] ; then
      if [ "${INSTALL_LOG}" = "y" ] && [ "x${N}" = "x" ] ; then
        CHROOT_wrt_LogNewFiles "$name"
      fi
    fi

    # Include a touch of the target name so make can check
    # if it's already been made.
    wrt_touch
    #
    #--------------------------------------------------------------------#
    #              >>>>>>>> END OF Makefile ENTRY <<<<<<<<               #
    #--------------------------------------------------------------------#

    # Keep the script file name for Makefile dependencies.
    PREV=${this_script}
    # Set system_build envar for iteration targets
    if [ -z "$N" ]; then
      system_build="$system_build $this_script"
    fi
  done # end for file in chapter06/*
  if [ -n "$N" ]; then
    system_build="$chapter6"
  fi
}
# NOT USED -- NOT USED
#----------------------------#
chapter78_Makefiles() {
#----------------------------#
  echo "${tab_}${GREEN}Processing... ${L_arrow}Chapter7/8   ( BOOT ) ${R_arrow}"

  for file in chapter0{7,8}/* ; do
    # Keep the script file name
    this_script=`basename $file`

    # Grub must be configured manually.
    # Handle fstab creation.
    # If no .config file is supplied, the kernel build is skipped
    case ${this_script} in
      *grub)    continue ;;
      *fstab)   [[ -z "${FSTAB}" ]] ||
                [[ ${FSTAB} == $BUILDDIR/sources/fstab ]] ||
                cp ${FSTAB} $BUILDDIR/sources/fstab ;;
      *kernel)  [[ -z ${CONFIG} ]] && continue
                [[ ${CONFIG} == $BUILDDIR/sources/kernel-config ]] ||
                cp ${CONFIG} $BUILDDIR/sources/kernel-config  ;;
    esac

    # First append each name of the script files to a list (this will become
    # the names of the targets in the Makefile
    chapter78="$chapter78 ${this_script}"

    #--------------------------------------------------------------------#
    #         >>>>>>>> START BUILDING A Makefile ENTRY <<<<<<<<          #
    #--------------------------------------------------------------------#
    #
    # Drop in the name of the target on a new line, and the previous target
    # as a dependency. Also call the echo_message function.
    CHROOT_wrt_target "${this_script}" "$PREV"

    # Find the bootscripts or networkscripts (for systemd)
    # and kernel package names
    case "${this_script}" in
      *bootscripts)
            name="lfs-bootscripts"
            if [ "${INSTALL_LOG}" = "y" ] ; then
              CHROOT_wrt_TouchTimestamp
            fi
        ;;
      *network-scripts)
            name="lfs-network-scripts"
            if [ "${INSTALL_LOG}" = "y" ] ; then
              CHROOT_wrt_TouchTimestamp
            fi
        ;;
      *kernel)
            name="linux"
            if [ "${INSTALL_LOG}" = "y" ] ; then
              CHROOT_wrt_TouchTimestamp
            fi
            # If using optimizations, use MAKEFLAGS (unless blacklisted)
            # no setting of CFLAGS and friends.
            [[ "$OPTIMIZE" != "0" ]] &&  wrt_makeflags "$name"
       ;;
    esac

      # Check if we have a real /etc/fstab file
    case "${this_script}" in
      *fstab) if [[ -n "$FSTAB" ]]; then
                CHROOT_wrt_CopyFstab
              else
                CHROOT_wrt_RunAsRoot "$file"
              fi
        ;;
      *)        CHROOT_wrt_RunAsRoot "$file"
        ;;
    esac

    case "${this_script}" in
      *bootscripts|*network-scripts|*kernel)
                         if [ "${INSTALL_LOG}" = "y" ] ; then
                           CHROOT_wrt_LogNewFiles "$name"
                         fi ;;
    esac
    # Include a touch of the target name so make can check
    # if it's already been made.
    wrt_touch
    #
    #--------------------------------------------------------------------#
    #              >>>>>>>> END OF Makefile ENTRY <<<<<<<<               #
    #--------------------------------------------------------------------#

    # Keep the script file name for Makefile dependencies.
    PREV=${this_script}
  done  # for file in chapter0{7,8}/*

}

#----------------------------#
build_Makefile() {           #
#----------------------------#

  echo "Creating Makefile... ${BOLD}START${OFF}"

  cd $JHALFSDIR/${PROGNAME}-commands

  # Start with empty files
  >$MKFILE
  >$MKFILE.tmp

  # Ensure the first dependency is empty
  unset PREV

  # We begin with the SETUP target; successive targets will be assigned in
  # the chapter_targets function.
  Makefile_target=SETUP_TGT

  # We need to know the chapter numbering, which depends on the version
  # of the book. Use the number of subdirs to know which version we have
  chaps=($(echo *))
  nb_chaps=${#chaps[*]} # 5 if classical version, 7 if new version
# DEBUG
#  echo chaps: ${chaps[*]}
#  echo nb_chaps: $nb_chaps
# end DEBUG

  # Make a temporary file with all script targets
  for (( i = 4; i < nb_chaps+4; i++ )); do
    chapter_targets $i
    if (( i ==  nb_chaps )); then : # we have finished temporary tools
      # Add the save target, if needed
      [[ "$SAVE_CH5" = "y" ]] && wrt_save_target $Makefile_target
    fi
    # TODO Add the iterations targets, if needed
    #  [[ "$COMPARE" = "y" ]] && wrt_compare_targets
  done
  # Add the CUSTOM_TOOLS targets, if needed
  [[ "$CUSTOM_TOOLS" = "y" ]] && wrt_CustomTools_target

  # Add a header, some variables and include the function file
  # to the top of the real Makefile.
  wrt_Makefile_header

  # Add chroot commands
  CHROOT_LOC="`whereis -b chroot | cut -d " " -f2`"
  i=1
  for file in ../chroot-scripts/*chroot* ; do
    chroot=`cat $file | \
            perl -pe 's|\\\\\n||g' | \
            tr -s [:space:] | \
            grep chroot | \
            sed -e "s|chroot|$CHROOT_LOC|" \
                -e 's|\\$|&&|g' \
                -e 's|"$$LFS"|$(MOUNT_PT)|'`
    echo -e "CHROOT$i= $chroot\n" >> $MKFILE
    i=`expr $i + 1`
  done

  # Store virtual kernel file systems commands:
  devices=`cat ../kernfs-scripts/devices.sh | \
            sed -e 's|^|	|'   \
                -e 's|mount|sudo &|' \
                -e 's|mkdir|sudo &|' \
                -e 's|\\$|&&|g' \
                -e 's|\$|; \\\\|' \
                -e 's|then|& :|' \
                -e 's|\$\$LFS|$(MOUNT_PT)|g'`
  teardown=`cat ../kernfs-scripts/teardown.sh | \
            sed -e 's|^|	|'   \
                -e 's|umount|sudo &|' \
                -e 's|\$LFS|$(MOUNT_PT)|'`
  teardownat=`cat ../kernfs-scripts/teardown.sh | \
              sed -e 's|^|	|'   \
                  -e 's|umount|@-sudo &|' \
                  -e 's|\$LFS|$(MOUNT_PT)|'`
  # Drop in the main target 'all:' and the chapter targets with each sub-target
  # as a dependency.
(
    cat << EOF

all:	ck_UID ck_terminal mk_SETUP mk_LUSER mk_SUDO mk_CHROOT mk_BOOT create-sbu_du-report mk_BLFS_TOOL mk_CUSTOM_TOOLS
$teardownat
	@sudo make do_housekeeping
EOF
) >> $MKFILE
if [ "$INITSYS" = systemd ]; then
(
    cat << EOF
	@/bin/echo -e -n \\
	NAME=\\"Linux From Scratch\\"\\\\n\\
	VERSION=\\"$VERSION\\"\\\\n\\
	ID=lfs\\\\n\\
	PRETTY_NAME=\\"Linux From Scratch $VERSION\\"\\\\n\\
	VERSION_CODENAME=\\"$(whoami)-jhalfs\\"\\\\n\\
	> os-release && \\
	sudo mv os-release \$(MOUNT_PT)/etc && \\
	sudo chown root:root \$(MOUNT_PT)/etc/os-release
EOF
) >> $MKFILE
fi
(
    cat << EOF
	@echo $VERSION > lfs-release && \\
	sudo mv lfs-release \$(MOUNT_PT)/etc && \\
	sudo chown root:root \$(MOUNT_PT)/etc/lfs-release
	@/bin/echo -e -n \\
	DISTRIB_ID=\\"Linux From Scratch\\"\\\\n\\
	DISTRIB_RELEASE=\\"$VERSION\\"\\\\n\\
	DISTRIB_CODENAME=\\"$(whoami)-jhalfs\\"\\\\n\\
	DISTRIB_DESCRIPTION=\\"Linux From Scratch\\"\\\\n\\
	> lsb-release && \\
	sudo mv lsb-release \$(MOUNT_PT)/etc && \\
	sudo chown root:root \$(MOUNT_PT)/etc/lsb-release
	@\$(call echo_finished,$VERSION)

ck_UID:
	@if [ \`id -u\` = "0" ]; then \\
	  echo "--------------------------------------------------"; \\
	  echo "You cannot run this makefile from the root account"; \\
	  echo "--------------------------------------------------"; \\
	  exit 1; \\
	fi

ck_terminal:
	@stty size | ( read L C; \\
	if (( L < 24 )) || (( C < 80 )) ; then \\
	  echo "--------------------------------------------------"; \\
	  echo "Terminal too small: \$\$C columns x \$\$L lines";\\
	  echo "Minimum: 80 columns x 24 lines";\\
	  echo "--------------------------------------------------"; \\
	  exit 1; \\
	fi )

mk_SETUP:
	@\$(call echo_SU_request)
	@sudo make save-luser
	@sudo make BREAKPOINT=\$(BREAKPOINT) SETUP
	@touch \$@

mk_LUSER: mk_SETUP
	@\$(call echo_SULUSER_request)
	@\$(SU_LUSER) "make -C \$(MOUNT_PT)/\$(SCRIPT_ROOT) BREAKPOINT=\$(BREAKPOINT) LUSER"
	@sudo make restore-luser
	@touch \$@

mk_SUDO: mk_LUSER
	@sudo rm -f envars
	@sudo make BREAKPOINT=\$(BREAKPOINT) SUDO
	@touch \$@

mk_CHROOT: mk_SUDO
	@\$(call echo_CHROOT_request)
	@( sudo \$(CHROOT1) -c "cd \$(SCRIPT_ROOT) && make BREAKPOINT=\$(BREAKPOINT) CHROOT")
	@touch \$@

mk_BOOT: mk_CHROOT
	@\$(call echo_CHROOT_request)
	@( sudo \$(CHROOT2) -c "cd \$(SCRIPT_ROOT) && make BREAKPOINT=\$(BREAKPOINT) BOOT")
	@touch \$@

mk_BLFS_TOOL: create-sbu_du-report
	@if [ "\$(ADD_BLFS_TOOLS)" = "y" ]; then \\
	  \$(call sh_echo_PHASE,Building BLFS_TOOL); \\
	  (sudo \$(CHROOT2) -c "make -C $BLFS_ROOT/work"); \\
	fi;
	@touch \$@

mk_CUSTOM_TOOLS: mk_BLFS_TOOL
	@if [ "\$(ADD_CUSTOM_TOOLS)" = "y" ]; then \\
	  \$(call sh_echo_PHASE,Building CUSTOM_TOOLS); \\
	  sudo mkdir -p ${BUILDDIR}${TRACKING_DIR}; \\
	  (sudo \$(CHROOT2) -c "cd \$(SCRIPT_ROOT) && make BREAKPOINT=\$(BREAKPOINT) CUSTOM_TOOLS"); \\
	fi;
	@touch \$@

devices: ck_UID
$devices
EOF
) >> $MKFILE
if [ "$INITSYS" = systemd ]; then
(
    cat << EOF
	sudo mkdir -pv \$(MOUNT_PT)/run/systemd/resolve
	sudo cp -v /etc/resolv.conf \$(MOUNT_PT)/run/systemd/resolve
EOF
) >> $MKFILE
fi
(
    cat << EOF

teardown:
$teardown

chroot1: devices
	sudo \$(CHROOT1)
	\$(MAKE) teardown

chroot: devices
	sudo \$(CHROOT2)
	\$(MAKE) teardown

SETUP:        $SETUP_TGT
LUSER:        $LUSER_TGT
SUDO:         $SUDO_TGT
EOF
) >> $MKFILE
if [ "$INITSYS" = systemd ]; then
(
    cat << EOF
	mkdir -pv \$(MOUNT_PT)/run/systemd/resolve
	cp -v /etc/resolv.conf \$(MOUNT_PT)/run/systemd/resolve

EOF
) >> $MKFILE
fi
(
    cat << EOF
CHROOT:       SHELL=\$(filter %bash,\$(CHROOT1))
CHROOT:       $CHROOT_TGT
BOOT:         $BOOT_TGT
CUSTOM_TOOLS: $custom_list

create-sbu_du-report:  mk_BOOT
	@\$(call echo_message, Building)
	@if [ "\$(ADD_REPORT)" = "y" ]; then \\
	  sudo ./create-sbu_du-report.sh logs $VERSION $(date --iso-8601); \\
	  \$(call echo_report,$VERSION-SBU_DU-$(date --iso-8601).report); \\
	fi
	@touch  \$@

save-luser:
	@\$(call echo_message, Building)
	@LUSER_ID=\$\$(grep '^\$(LUSER):' /etc/passwd | cut -d: -f3); \\
	if [ -n "\$\$LUSER_ID" ]; then  \\
	    if [ ! -d \$(LUSER_HOME).XXX ]; then \\
		mv \$(LUSER_HOME){,.XXX}; \\
		mkdir \$(LUSER_HOME); \\
		chown \$(LUSER):\$(LGROUP) \$(LUSER_HOME); \\
	    fi; \\
	    echo "\$\$LUSER_ID" > luser-id; \\
	    echo User \$(LUSER) exists with ID \$\$LUSER_ID; \\
	else \\
	    rm -f luser-id; \\
	    echo User \$(LUSER) does not exist; \\
	    echo It will be created with book instructions.; \\
	fi
	@\$(call housekeeping)

restore-luser:
	@\$(call echo_message, Building)
	@if [ -f luser-id ]; then \\
		rm -rf \$(LUSER_HOME); \\
		mv \$(LUSER_HOME){.XXX,}; \\
		rm luser-id; \\
	else \\
		userdel \$(LUSER); \\
		groupdel \$(LGROUP); \\
		rm -rf \$(LUSER_HOME); \\
	fi
	@\$(call housekeeping)

do_housekeeping:
	@-rm /tools

EOF
) >> $MKFILE

  # Bring over the items from the Makefile.tmp
  cat $MKFILE.tmp >> $MKFILE
  rm $MKFILE.tmp
  echo "Creating Makefile... ${BOLD}DONE${OFF}"
}
