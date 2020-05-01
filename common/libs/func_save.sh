# $Id: func_compare.sh 3824 2015-03-07 22:05:24Z pierre $

#----------------------------------#
wrt_save_target() {            #
#----------------------------------#

    local target
    case $1 in
        runasroot) target=SUDO ;;
        chapter6 ) target=CHROOT ;;
    esac
    CHROOT_wrt_target save-ch5 "$PREV";
    wrt_save_work $target
    wrt_touch
    PREV=save-ch5
    eval $1=\"\$$1 save-ch5\"
}

#----------------------------------#
wrt_save_work() {               #
#----------------------------------#
  local    ROOT_DIR
  case x"$1" in
      xSUDO  ) ROOT_DIR="$BUILDDIR/" ;;
      xCHROOT) ROOT_DIR=/          ;;
  esac

  local PRUNEPATH="./dev ./home ./lost+found ./media ./mnt ./opt ./proc ./root ./run ./srv ./sys ./tmp ./var"
  local DEST_TOPDIR="${ROOT_DIR}${SCRIPT_ROOT}"

(
    cat << EOF
	@mkdir -p /tmp >>logs/\$@ 2>&1 && \\
	TARNAME=chapter5-\$\$(date -Iseconds).tar && \\
        TMPFILE=\$\$(mktemp -p /tmp) && \\
        TMPLOG=\$\$(mktemp -p /tmp) && \\
	for F in $PRUNEPATH; do echo \$\$F >> \$\$TMPFILE; done && \\
	tar -X \$\$TMPFILE -cvf /tmp/\$\$TARNAME -C ${ROOT_DIR} . >>\$\$TMPLOG 2>>logs/\$@ && \\
	cat \$\$TMPLOG >>logs/\$@ 2>&1 && \\
	mv /tmp/\$\$TARNAME $DEST_TOPDIR >>logs/\$@ 2>&1 && \\
	rm \$\$TMPFILE \$\$TMPLOG
EOF
) >> $MKFILE.tmp

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
