# $Id$

#----------------------------------#
wrt_compare_targets() {            #
#----------------------------------#

  for ((N=1; N <= ITERATIONS ; N++)) ; do # Double parentheses,
                                          # and "ITERATIONS" with no "$".
    ITERATION=iteration-$N
    if [ "$N" != "1" ] ; then
      wrt_system_build "$1" "$N" "$PREV_IT"
    fi
    # add needed Makefile target
    this_script=$ITERATION
    CHROOT_wrt_target "$ITERATION" "$PREV"
    wrt_compare_work "$ITERATION" "$PREV_IT"
    wrt_logs "$N"
    wrt_touch
    PREV_IT=$ITERATION
    PREV=$ITERATION
  done
  # We need to prevent "userdel" in all iterations but the last
  # We need to access the scriptlets in "dir"
  local dir
  printf -v dir chapter%02d "$1"

  sed -i '/userdel/d' $dir/*revised*
  for (( N = 2; N < ITERATIONS; N++ )); do
     sed -i '/userdel/d' $dir-build_$N/*revised*
  done

}

#----------------------------------#
wrt_system_build() {               #
#----------------------------------#
  local    CHAP=$1
  local     RUN=$2
  local PREV_IT=$3

  if [[ "$PROGNAME" = "clfs" ]] ; then
    final_system_Makefiles $RUN
  else
    chapter_targets $CHAP $RUN
  fi

  if [[ "$PROGNAME" = "clfs" ]] ; then
    basicsystem="$basicsystem $PREV_IT $system_build"
  else
    CHROOT_TGT="$CHROOT_TGT $PREV_IT $system_build"
  fi

  if [[ "$RUN" = "$ITERATIONS" ]] ; then
    if [[ "$PROGNAME" = "clfs" ]] ; then
      basicsystem="$basicsystem iteration-$RUN"
    else
      CHROOT_TGT="$CHROOT_TGT iteration-$RUN"
    fi
  fi
}

#----------------------------------#
wrt_compare_work() {               #
#----------------------------------#
  local ITERATION=$1
  local   PREV_IT=$2
  local PRUNEPATH="/dev /home /${SCRIPT_ROOT} /lost+found /media /mnt /opt /proc \
/sources /root /run /srv /sys /tmp /tools /usr/local /usr/src /var"

  local    ROOT_DIR=/
  local DEST_TOPDIR=/${SCRIPT_ROOT}
  local   ICALOGDIR=/${SCRIPT_ROOT}/logs/ICA

  if [[ "$RUN_ICA" = "y" ]] ; then
    local DEST_ICA=$DEST_TOPDIR/ICA && \
  # the PRUNEPATH additional setting is to avoid .pyc files to show up in diff
(
    cat << EOF
	@PRUNEPATH="$PRUNEPATH \$\$(find /usr/lib -name __pycache__)"; \\
	extras/do_copy_files "\$\$PRUNEPATH" $ROOT_DIR $DEST_ICA/$ITERATION >>logs/\$@ 2>&1 && \\
	extras/do_ica_prep $DEST_ICA/$ITERATION >>logs/\$@ 2>&1
EOF
) >> $MKFILE.tmp
    if [[ "$ITERATION" != "iteration-1" ]] ; then
      wrt_do_ica_work "$PREV_IT" "$ITERATION" "$DEST_ICA"
    fi
  fi
}

#----------------------------------#
wrt_do_ica_work() {                #
#----------------------------------#
  echo -e "\t@extras/do_ica_work $1 $2 $ICALOGDIR $3 >>logs/\$@ 2>&1" >> $MKFILE.tmp
}

#----------------------------------#
wrt_logs() {                       #
#----------------------------------#
  local build=build_$1
  local file

(
    cat << EOF
	@cd logs && \\
	mkdir $build && \\
	mv -f `echo ${system_build} | sed 's/ /* /g'`* $build && \\
	if [ ! $build = build_1 ] ; then \\
	  cd $build && \\
	  for file in \`ls .\` ; do \\
	    mv -f \$\$file \`echo \$\$file | sed -e 's,-$build,,'\` ; \\
	  done ; \\
	fi
	@cd /\$(SCRIPT_ROOT)
	@if [ -d test-logs ] ; then \\
	  cd test-logs && \\
	  mkdir $build && \\
	  mv -f `echo ${system_build} | sed 's/ /* /g'`* $build && \\
	  if [ ! $build = build_1 ] ; then \\
	    cd $build && \\
	    for file in \`ls .\` ; do \\
	      mv -f \$\$file \`echo \$\$file | sed -e 's,-$build,,'\` ; \\
	    done ; \\
	  fi ; \\
	  cd /\$(SCRIPT_ROOT) ; \\
	fi ;
EOF
) >> $MKFILE.tmp
}
