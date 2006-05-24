#!/bin/bash
#
# $Id$
#
set -e
declare TARGET
declare DEP_LEVEL
declare PKGXML
declare BLFS_XML
declare VERBOSITY=1

# Grab and name the command line options
    optTARGET=$1 
optDEPENDENCY=$2


#---------------------
# Constants
source constants.inc
[[ $? > 0 ]] && echo -e "\n\tERROR: constants.inc did not load..\n" && exit

#---------------------
# Configuration file for alternatives
source alternatives.conf
[[ $? > 0 ]] && echo -e "\n\tERROR: alternatives.conf did not load..\n" && exit

#---------------------
# Dependencies module
source func_dependencies
[[ $? > 0 ]] && echo -e "\n\tERROR: func_dependencies did not load..\n" && exit



#-------------------------#
validate_target() {       # ID of target package (as listed in packages file)
#-------------------------#
: <<inline_doc
    function:   Validate the TARGET parameter. 
    input vars: $1, package/target to validate
    externals:  file: packages
    modifies:   TARGET
    returns:    nothing
    output:     nothing
    on error:   exit
    on success: modifies TARGET 
inline_doc

  if [[ -z "$1" ]] ; then
    echo -e "\n\tYou must to provide a package ID."
    echo -e "\tSee packages file for a list of available targets.\n"
    exit 1
  fi

  if ! grep  "^$1[[:space:]]" packages > /dev/null ; then
    echo -e "\n\t$1 is not a valid package ID."
    echo -e "\tSee packages file for a list of available targets.\n"
    exit 1
  fi

  case $1 in
    xorg7 )
      TARGET=xterm2
      echo -e "\n\tUsing $TARGET as the target package"
      echo -e "to build the Xorg7 meta-package."
      ;;
    * )
      TARGET=$1
      echo -e "\n\tUsing $TARGET as the target package."
      ;;
  esac
}

#-------------------------#
validate_dependency() {   # Dependencies level 1(required)/2(1 + recommended)/3(2+ optional)
#-------------------------#
: <<inline_doc
    function:   Validate the dependency level requested. 
    input vars: $1, requested dependency level
    externals:  vars: TARGET
    modifies:   vars: DEP_LEVEL
    returns:    nothing
    output:     nothing
    on error:   nothing
    on success: modifies DEP_LEVEL, default value = 2
inline_doc

  if [[ -z "$1" ]] ; then
    DEP_LEVEL=2
    echo -e "\n\tNo dependencies level has been defined."
    echo -e "\tAssuming level $DEP_LEVEL (Required plus Recommended).\n"
    return
  fi

  case $1 in
    1 | 2 )
      DEP_LEVEL=$1
      echo -e "\n\tUsing $DEP_LEVEL as dependencies level.\n"
      ;;
      # Prevent circular dependencies when level 3
      # cracklib-->python-->tk-->X-->linux-pam-->cracklib
      # docbook-utils--> Optional dependencies are runtime only
      # libxml2-->libxslt-->libxml2
      # cyrus-sasl-->openldap-->cyrus-sasl
      # alsa-lib-->doxygen-->graphviz-->jdk-->alsa-lib
      # unixodbc-->qt-->unixodbc
      # cups-->php-->sendmail-->espgs-->cups
      # libexif-->graphviz-->php-->libexif
      # esound-->aRts-->esound
      # gimp-->imagemagick-->gimp
    3 )
      case $TARGET in
        cracklib | docbook-utils | libxml2 | cyrus-sasl | alsa-lib | \
        unixodbc | cups | libexif | esound | gimp )
          DEP_LEVEL=2
          echo -e "\n\t$TARGET have circular dependencies at level $1"
          echo -e "\tUsing $DEP_LEVEL as dependencies level.\n"
          ;;
        * )
          DEP_LEVEL=$1
          echo -e "\n\tUsing $DEP_LEVEL as dependencies level.\n"
          ;;
      esac
      ;;
    * )
      DEP_LEVEL=2
      echo -e "\n\t$1 is not a valid dependencies level."
      echo -e "\tAssuming level $DEP_LEVEL (Required plus Recommended).\n"
      ;;
  esac
}





#------- MAIN --------
if [[ ! -f packages ]] ; then
  echo -e "\tNo packages file has been found.\n"
  echo -e "\tExecution aborted.\n"
  exit 1
fi

validate_target     "${optTARGET}"
validate_dependency "${optDEPENDENCY}"
generate_dependency_tree
generate_TARGET_xml
generate_target_book
create_build_scripts
