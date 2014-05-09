#!/bin/bash
# short script to setup a new experiment and/or re-link restart files
# Andre R. Erler, 02/03/2013, GPL v3

VERBOSITY=${VERBOSITY:-1} # output verbosity

## figure out what we are doing
if [[ "${MODE}" == 'NOGEO'* ]]; then
  # cold start without geogrid
  NOGEO='NOGEO' # run without geogrid
  NOTAR='FALSE' # star static
  RESTART='FALSE' # cold start
elif [[ "${MODE}" == 'NOSTAT'* ]]; then
  # cold start without geogrid
  NOGEO='NOGEO' # run without geogrid
  NOTAR='NOTAR' # star static
  RESTART='FALSE' # cold start
elif [[ "${MODE}" == 'RESTART' ]]; then
  # restart run (no geogrid)
  RESTART='RESTART' # restart previously terminated run
  NOGEO='NOGEO' # run without geogrid
  NOTAR='FALSE' # star static
elif [[ "${MODE}" == 'CLEAN' ]] || [[ "${MODE}" == '' ]]; then
  # cold start with geogrid
  NOGEO='FALSE' # run with geogrid
  NOTAR='FALSE' # star static
  RESTART='FALSE' # cold start
else
  echo
  echo "   >>>   Unknown command ${MODE} - aborting!!!   "
  echo
  exit 1
fi

# launch feedback
if [ $VERBOSITY -gt 0 ]; then
	echo
	if [[ "${RESTART}" == 'RESTART' ]]
	 then
	  echo "   ***   Re-starting Cycle  ***   "
	  echo
	  echo "   Next Step: ${NEXTSTEP}"
	 else
	  echo "   ***   Starting Cycle  ***   "
	  echo
	  echo "   First Step: ${NEXTSTEP}"
	fi
	echo
	echo "   Root Dir: ${INIDIR}"
	echo
fi # $VERBOSITY
cd "${INIDIR}"

## run geogrid
if [[ "${NOGEO}" == 'NOGEO' ]]
 then
  [ $VERBOSITY -gt 0 ] && echo "   Not running geogrid.exe"
 else
  # clear files
  rm -f geo_em.d??.nc geogrid.log*
  # run with parallel processes
  [ $VERBOSITY -gt 0 ] && echo "   Running geogrid.exe (suppressing output)"
  if [ $VERBOSITY -gt 1 ]
    then eval "${RUNGEO}" # command specified in caller instance
    else eval "${RUNGEO}" > /dev/null # swallow output
  fi # $VERBOSITY
fi
[ $VERBOSITY -gt 0 ] && echo

## if not restarting, setup initial and run directories
if [[ "${RESTART}" == 'RESTART' ]]; then # restart

  ## restart previous cycle
  # read date string for restart file
  RSTDATE=$(sed -n "/${NEXTSTEP}/ s/${NEXTSTEP}[[:space:]]\+.\(.*\).[[:space:]].*$/\1/p" stepfile)
  NEXTDIR="${INIDIR}/${NEXTSTEP}" # next $WORKDIR
  cd "${NEXTDIR}"
  # link restart files
  [ $VERBOSITY -gt 0 ] && echo "Linking restart files to next working directory:"
  [ $VERBOSITY -gt 0 ] && echo "${NEXTDIR}"
  for RST in "${WRFOUT}"/wrfrst_d??_"${RSTDATE}"; do
    ln -sf "${RST}" 
    [ $VERBOSITY -gt 0 ] && echo  "${RST}"
  done

else # cold start

  ## start new cycle
  # clear some folders
  [ $VERBOSITY -gt 0 ] && echo "   Clearing Output Folders:"
  if [[ -n ${METDATA} ]]; then
    [ $VERBOSITY -gt 0 ] && echo "${METDATA}"
    if [[ "${MODE}" == 'CLEAN' ]]; then rm -rf "${METDATA}"; fi
    mkdir -p "${METDATA}"
  fi
  if [[ -n ${WRFOUT} ]]; then
    [ $VERBOSITY -gt 0 ] && echo "${WRFOUT}"
    if [[ "${MODE}" == 'CLEAN' ]]; then rm -rf "${WRFOUT}"; fi
    mkdir -p "${WRFOUT}"
  fi
  [ $VERBOSITY -gt 0 ] && echo

  # prepare first working directory
  # set restart to False for first step
  sed -i '/restart\ / s/restart\ *=\ *\.true\..*$/restart = .false.,/' "${INIDIR}/${NEXTSTEP}/namelist.input"
  # and make sure the rest is on restart
  sed -i '/restart\ / s/restart\ *=\ *\.false\..*$/restart = .true.,/' "${INIDIR}/namelist.input"
  [ $VERBOSITY -gt 0 ] && echo "   Setting restart option and interval in namelist."


  # create backup of static files
  if [[ "${NOTAR}" != 'NOTAR' ]]; then
    cd "${INIDIR}"
    rm -rf 'static/'
    mkdir -p 'static'
    echo $( cp -P * 'static/' &> /dev/null ) # trap this error and hide output
    cp -rL 'scripts/' 'bin/' 'meta/' 'tables/' 'static/'
    tar cf - 'static/' | gzip > "${STATICTGZ}"
    rm -r 'static/'
    mv "${STATICTGZ}" "${WRFOUT}"
    if [ $VERBOSITY -gt 0 ]; then
	    echo "   Saved backup file for static data:"
	    echo "${WRFOUT}/${STATICTGZ}"
	    echo
    fi # $VERBOSITY
  fi # if not LASTSTEP==NOTAR

fi # if restart
[ $VERBOSITY -gt 0 ] && echo
