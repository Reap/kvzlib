#!/bin/bash
set +x
#/**
# * Takes source from ./bash.dev programs, recursively follows (function) includes, 
# * and compiles standalone bash programs in ./bash
# * 
# * @author    Kevin van Zonneveld <kevin@vanzonneveld.net>
# * @copyright 2008 Kevin van Zonneveld (http://kevin.vanzonneveld.net)
# * @license   http://www.opensource.org/licenses/bsd-license.php New BSD Licence
# * @version   SVN: Release: $Id$
# * @link      http://kevin.vanzonneveld.net/
# * 
# */

# Includes
###############################################################
source $(echo "$(dirname ${0})/functions/log.sh")
source $(echo "$(dirname ${0})/functions/commandTestHandle.sh")
source $(echo "$(dirname ${0})/functions/commandTest.sh")
source $(echo "$(dirname ${0})/functions/commandInstall.sh")
source $(echo "$(dirname ${0})/functions/toUpper.sh")
source $(echo "$(dirname ${0})/functions/getWorkingDir.sh")

# Check for program requirements
###############################################################
commandTestHandle "bash" "bash" "EMERG" "NOINSTALL"
commandTestHandle "aptitude" "aptitude" "DEBUG" "NOINSTALL" # Just try to set CMD_APTITUDE, produces DEBUG msg if not found
commandTestHandle "egrep" "pcregrep"
commandTestHandle "awk"
commandTestHandle "tail"
commandTestHandle "head"
commandTestHandle "sort"
commandTestHandle "uniq"
commandTestHandle "realpath"

OUTPUT_DEBUG=1
DIR_ROOT=$(getWorkingDir "/..");
DIR_SORC="${DIR_ROOT}/bash.dev"
DIR_DEST="${DIR_ROOT}/bash"

# Loop through BASH 'programs'
for filePathSource in $(find ${DIR_SORC}/*/ -type f -name '*.sh'); do
	
    fileSourceBase=$(basename ${filePathSource})
	
    # Determine compiled version path
    filePathDest=$(echo "${filePathSource}" |sed "s#${DIR_SORC}#${DIR_DEST}#g")
	log "${filePathSource} --> ${filePathDest}" "INFO"
    
    # Grep 'make::'includes
	depTxt=$(cat ${filePathSource} |grep '# make::include')
	depsAdded=0

    srcLines=$(cat ${filePathSource} |wc -l)
    depAt=$(cat ${filePathSource} |grep -n '# make::include' |head -n1 |awk -F':' '{print $1}')
    [ -n "${depAt}" ] || depAt=0
    let linesRemain=srcLines-depAt
    
    # Reset destination file
    echo "#!/bin/bash" |tee ${filePathDest}
    [ -f ${filePathDest} ] || log "Unable to create file: '${filePathDest}'" "EMERG"
    chmod a+x ${filePathDest}
    
    # Add head of original source
    cat ${filePathSource} |head -n ${depAt} |egrep -v '(# make::include|#!/bin/bash)' |tee -a ${filePathDest} 
	
	# Walk through include lines
	for depPart in ${depTxt}; do
		# Extract filename 
		[[ ${depPart} =~ (/([\.a-zA-Z0-9\/]+)+) ]]
		depFile=${BASH_REMATCH[1]}
		
		# Include filename matched?
		if [ -n "${depFile}" ]; then
			# Create real path from include reference
		    realDepFile=$(realpath ${DIR_SORC}/programs/${depFile})
		    realDepBase=$(basename ${realDepFile} ".sh")
		    
		    # Real include path exists? 
			if [ ! -f "${realDepFile}" ]; then
				log "Include path '${realDepFile}' does not exist!" "EMERG"
			else
			    log "Added include: '${realDepBase}' to '${fileSourceBase}'" "DEBUG"
			fi
			
			# Add dependency
			let depsAdded=depsAdded+1
			echo "" |tee -a ${filePathDest}
			echo "# ('${realDepBase}' included from '${depFile}')" |tee -a ${filePathDest}
			cat ${realDepFile}  |tee -a ${filePathDest}
			echo "" |tee -a ${filePathDest}
		fi
	done
	
	if [ "${depsAdded}" -gt 0 ]; then
		log "Added ${depsAdded} includes for: '${fileSourceBase}'" "DEBUG"
	fi
	
    # Add remainder of original source
    cat ${filePathSource} |tail -n ${linesRemain} |egrep -v '(# make::include|#!/bin/bash)' |tee -a ${filePathDest} 
done