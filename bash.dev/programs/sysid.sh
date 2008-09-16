#!/bin/bash
#/**
# * Displays detailed system information
# * Like serial number, operation system, memory, etc.
# * 
# * @author    Kevin van Zonneveld <kevin@vanzonneveld.net>
# * @copyright 2007 Kevin van Zonneveld (http://kevin.vanzonneveld.net)
# * @license   http://www.opensource.org/licenses/bsd-license.php New BSD Licence
# * @version   SVN: Release: $Id$
# * @link      http://kevin.vanzonneveld.net/
# *
# */

# Includes
###############################################################
source $(echo "$(dirname ${0})/../functions/log.sh")     # make::include
source $(echo "$(dirname ${0})/../functions/toUpper.sh") # make::include
source $(echo "$(dirname ${0})/../functions/commandInstall.sh") # make::include
source $(echo "$(dirname ${0})/../functions/commandTest.sh") # make::include
source $(echo "$(dirname ${0})/../functions/commandTestHandle.sh") # make::include
source $(echo "$(dirname ${0})/../functions/getWorkingDir.sh") # make::include

# Check for program requirements
###############################################################
commandTestHandle "bash" "bash" "EMERG" "NOINSTALL"
commandTestHandle "aptitude" "aptitude" "DEBUG" "NOINSTALL" # Just try to set CMD_APTITUDE, produces DEBUG msg if not found
commandTestHandle "awk"
commandTestHandle "grep"
commandTestHandle "egrep"
commandTestHandle "sed"
commandTestHandle "uniq"
commandTestHandle "sort"
commandTestHandle "cat"
commandTestHandle "realpath"

commandTestHandle "head"
commandTestHandle "free"
commandTestHandle "df"
commandTestHandle "uname"

# For windows put this in a .VBS file:
#
# strComputer = "."
# Set objWMIService = GetObject("winmgmts:" & "{impersonationLevel=impersonate}!\\" &
# strComputer & "\root\cimv2")
#
# Set colSMBIOS = objWMIService.ExecQuery ("Select * from Win32_SystemEnclosure")
#
# For Each objSMBIOS in colSMBIOS
#   Wscript.Echo "Serial Number: " & objSMBIOS.SerialNumber
# Next

# Run
###############################################################

# If available, dmidecode delivers valuable data like Service Tags
if [ -x /usr/sbin/dmidecode ]; then
    /usr/sbin/dmidecode \
    |${CMD_SED} 's#^[\t| ]*##g' \
    |${CMD_EGREP} '(^Serial Number: [a-zA-Z0-9]{7}$|^Product Name: [A-Z]|^Socket Designation: |^Heigth: |^Maximum Capacity: [0-9]{1})' \
    |${CMD_EGREP} -v '(Not Specified$|DIMM|BANK|Cache|A0$|A1$|A2$|A3$)' \
    |${CMD_SED} \
     -e 's#^Serial Number:#Service Tag:#g' \
     -e 's#^Socket Designation:#CPU Socket:#g' \
     -e 's#^Maximum Capacity:#Memory Maximum Capacity:#g' \
     -e 's#@# #g' \
    |${CMD_SORT} \
    |${CMD_UNIQ}
fi

# Memory
${CMD_FREE} -b |${CMD_AWK} '/Mem/ {printf "Memory Netto Size: %1.1f GB\n", ($2/(1024*1024*1024))}'

# Disk
${CMD_DF} -lTP |${CMD_GREP} '/dev/' |${CMD_AWK} '/ext2|ext3|xfs/ {sum+=$3} END {printf "Disk Netto Size: %1.1f GB\n", (sum/(1024*1024))}'

# CPUs
${CMD_CAT} /proc/cpuinfo \
    |${CMD_EGREP} '(model name|cpu MHz)' \
    |${CMD_HEAD} -n2 \
    |${CMD_SED} 's#[[:space:]]*:#:#g' \
    |${CMD_SED} \
     -e 's#^model name:#CPU Model:#g' \
     -e 's#^cpu MHz:#CPU MHz:#g'
     
# OS & Kernel
echo -n "Operating System: "
if [ -f /etc/lsb-release ];then
    OS="`echo $(${CMD_CAT} /etc/lsb-release |${CMD_AWK} -F'=' '{print $2}' |${CMD_HEAD} -n3)`"
elif [ -f /etc/redhat-release ]; then
    OS="`echo $(${CMD_CAT} /etc/redhat-release)`"
else
    OS="Unknown"
fi
echo "${OS} ("$(${CMD_UNAME} -m)")"