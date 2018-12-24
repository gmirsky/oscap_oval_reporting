#!/bin/bash
# OSCAP/OVAL report and remediation script creation.
#
# Run as root or sudo su
#
#set -x
if [ "$EUID" -ne 0 ]; then
  echo "This script requires elevated permissions."
  echo "Please run this script as sudo or root."
  exit
fi
#
# get the positional parameters if they were supplied by the user
#
SPACEWALK="NO"
VERBOSE="NO"
HELP="NO"
#
POSITIONAL=()
while [[ $# -gt 0 ]]
do
  key="$1"
  #
  case $key in
      -d|--destination)
      DESTINATION="$2"
      shift # past argument
      shift # past value
      ;;
      -h|--help)
      HELP="YES"
      shift # past argument
      ;;
      -v|--verbose)
      VERBOSE="YES"
      shift # past argument
      ;;
      -s|--spacewalk)
      SPACEWALK="YES"
      shift # past argument
      ;;
      *)    # unknown option
      POSITIONAL+=("$1") # save it in an array for later
      shift # past argument
      ;;
  esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters
#
# if the help option was selected.
#
if [ "${HELP}" == "YES" ]; then
  echo
  echo -e "\e[1mNAME\e[0m"
  echo
  echo "  Security Content Automation Protocol (SCAP) "
  echo "  Open Vulnerability and Assessment Language (OVAL®)"
  echo "  Reporting script"
  echo
  echo -e "\e[1mSYNOPSIS\e[0m"
  echo
  echo "  oscapOvalReporting.sh [OPTION]... [FILE]"
  echo
  echo -e "\e[1mDESCRIPTION\e[0m"
  echo
  echo "  -d, --destination... [FILE]"
  echo
  echo "    Destination directory for the output reports. Otherwise reports"
  echo "    will be created in the current directory."
  echo
  echo "  -h, --help"
  echo
  echo "    Display this help and exit."
  echo
  echo "  -s, --spacewalk"
  echo
  echo "    Install Spacewalk OSCAP packages if not installed already."
  echo "    This allows users to run OSCAP reports directly in Spacewalk."
  echo "    See Spacewalk documentation for more details"
  echo
  echo " -v, --verbose"
  echo
  echo "    Show all output to standard out."
  echo
  exit
fi
#
# Acknowledge the user has selected the verbose option.
#
if [ "${VERBOSE}" == "YES" ]; then
  echo
  echo "Executing in verbose mode."
fi
#
# check to see if the prerequisite packages have been installed. if not, then
# install them.
#
if [ "${SPACEWALK}" == "YES" ]; then
  YUM_PACKAGES="openscap openscap-utils scap-security-guide spacewalk-oscap"
else
  YUM_PACKAGES="openscap openscap-utils scap-security-guide"
fi
#
if [ "${VERBOSE}" == "YES" ]; then
  echo "Checking for prerequisite packages."
fi
#
for i in  ${YUM_PACKAGES[*]}
 do
  isinstalled=$(rpm -q $i)
  if [ !  "$isinstalled" == "package $i is not installed" ];
   then
     if [ "${VERBOSE}" == "YES" ]; then
       echo "   Verified that package $i is already installed."
     fi
  else
    if [ "${VERBOSE}" == "YES" ]; then
      echo "$i is not installed. Installing package now."
    fi
    yum install $i -y
  fi
done
#
# if destination directory was not provided then use the current directory.
#
if [ -z "${DESTINATION}" ]
then
      DESTINATION="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
else
      #CURRENT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
      #
      # if the destination directorywas provided then check to see
      #
      if [ -d "${DESTINATION}" ]
      then
          # remove the trailing slashe(s) with realpath.
          DESTINATION=$(realpath -s $DESTINATION)
      else
          echo
          echo "Error: Directory ${DESTINATION} does not exists."
          echo "Please insure that the destination parameter is correct or"
          echo "create the destination directory with the proper permissions."
          echo "Aborting."
          exit
      fi
fi
#
if [ "${VERBOSE}" == "YES" ]; then
  echo
  echo "DESTINATION PATH"  = "${DESTINATION}"
  echo "VERBOSE"         = "${VERBOSE}"
  echo "SPACEWALK"       = "${SPACEWALK}"
fi
#
D1=$(date +"%Y%m%d%H%M%S")
CPE_DICTIONARY="/usr/share/xml/scap/ssg/content/ssg-rhel7-cpe-dictionary.xml"
REMEDIATION_SCRIPT="$DESTINATION/$(hostname).$D1.remediation.sh"
OSCAP_RESULTS="$DESTINATION/$(hostname)-scap-results-$D1.xml"
OVAL_RESULTS="$DESTINATION/$(hostname)-oval-results-$D1.xml"
OSCAP_REPORT="$DESTINATION/$(hostname)-scap-report-$D1.html"
OVAL_REPORT="$DESTINATION/$(hostname)-oval-report-$D1.html"
#TAB="     "

XCCDF_FILE="/usr/share/xml/scap/ssg/content/ssg-centos7-xccdf.xml"
OVAL_FILE="/usr/share/xml/scap/ssg/content/ssg-rhel7-oval.xml"
#
# Get the operating system details to see if this script is running on the
# correct platform.
#
lowercase(){
    echo "$1" | sed "y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/"
}
#
OS=`lowercase \`uname\``
KERNEL=`uname -r`
MACH=`uname -m`
#
if [ "{$OS}" == "windowsnt" ]; then
    OS=windows
elif [ "{$OS}" == "darwin" ]; then
    OS=mac
else
    OS=`uname`
    if [ "${OS}" = "SunOS" ] ; then
        OS=Solaris
        ARCH=`uname -p`
        OSSTR="${OS} ${REV}(${ARCH} `uname -v`)"
    elif [ "${OS}" = "AIX" ] ; then
        OSSTR="${OS} `oslevel` (`oslevel -r`)"
    elif [ "${OS}" = "Linux" ] ; then
        if [ -f /etc/redhat-release ] ; then
            DistroBasedOn='RedHat'
            DIST=`cat /etc/redhat-release |sed s/\ release.*//`
            PSUEDONAME=`cat /etc/redhat-release | sed s/.*\(// | sed s/\)//`
            REV=`cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*//`
        elif [ -f /etc/SuSE-release ] ; then
            DistroBasedOn='SuSe'
            PSUEDONAME=`cat /etc/SuSE-release | tr "\n" ' '| sed s/VERSION.*//`
            REV=`cat /etc/SuSE-release | tr "\n" ' ' | sed s/.*=\ //`
        elif [ -f /etc/mandrake-release ] ; then
            DistroBasedOn='Mandrake'
            PSUEDONAME=`cat /etc/mandrake-release | sed s/.*\(// | sed s/\)//`
            REV=`cat /etc/mandrake-release | sed s/.*release\ // | sed s/\ .*//`
        elif [ -f /etc/debian_version ] ; then
            DistroBasedOn='Debian'
            DIST=`cat /etc/lsb-release | grep '^DISTRIB_ID' | awk -F=  '{ print $2 }'`
            PSUEDONAME=`cat /etc/lsb-release | grep '^DISTRIB_CODENAME' | awk -F=  '{ print $2 }'`
            REV=`cat /etc/lsb-release | grep '^DISTRIB_RELEASE' | awk -F=  '{ print $2 }'`
        fi
        if [ -f /etc/UnitedLinux-release ] ; then
            DIST="${DIST}[`cat /etc/UnitedLinux-release | tr "\n" ' ' | sed s/VERSION.*//`]"
        fi
        OS=`lowercase $OS`
        DistroBasedOn=`lowercase $DistroBasedOn`
        readonly OS
        readonly DIST
        readonly DistroBasedOn
        readonly PSUEDONAME
        readonly REV
        readonly KERNEL
        readonly MACH
    fi
fi
#
# trim trailing spaces and lowercase the results to standardize the
# comparisons
#
DIST1="$(echo -e "${DIST}" | tr -d '[:space:]')"
DIST2="${DIST1,,}"
if [ "$DIST2" != "centoslinux" ]; then
  echo
  echo "Distribution: $DIST is not supported by this script."
  echo "Aborting."
  echo
  exit
fi
#
MAJOR_REVISION="${REV%%.*}"
if [ "$MAJOR_REVISION" != "7" ]; then
  echo
  echo "Distribution/Revision: $DIST $MAJOR_REVISION is not supported by this script."
  echo "Aborting."
  exit
else
  if [ "${VERBOSE}" == "YES" ]; then
    echo
    echo "Distribution: "$DIST  $MAJOR_REVISION " is OK."
    echo
  fi
fi
#
# Check to see if the required files are present.
#
if [ -e "${CPE_DICTIONARY}" ]
then
  if [ "${VERBOSE}" == "YES" ]; then
    echo
    echo "Found the Common Platform Enumeration (CPE) dictionary at: " $CPE_DICTIONARY
  fi
else
    echo
    echo "The Common Platform Enumeration (CPE) dictionary was not found at: " $CPE_DICTIONARY
    echo "Aborting."
    exit
fi
#
if [ -e "${XCCDF_FILE}" ]
then
  if [ "${VERBOSE}" == "YES" ]; then
    echo
    echo "Found the Extensible Configuration Checklist Description Format (XCCDF) file at: " $CPE_DICTIONARY
  fi
else
    echo
    echo "The Extensible Configuration Checklist Description Format (XCCDF) file was not found at: " $CPE_DICTIONARY
    echo "Aborting."
    exit
fi
#
# Run the OSCAP scan
#
if [ "${VERBOSE}" == "YES" ]; then
  echo
  echo "Creating OSCAP scan report."
fi
#
# Run the oscap report
#
 oscap xccdf eval --profile server --results $OSCAP_RESULTS --report $OSCAP_REPORT --oval-results --fetch-remote-resources --cpe $CPE_DICTIONARY $XCCDF_FILE
#
# In order to generate a script to fix all identified deficiencies with the
# system (and improve the overall score), we need to know our report result-id
# so we can run it with this command using the results xml file.
#
RESULTID=$(grep TestResult $OSCAP_RESULTS | awk -F\" '{ print $2 }')
#
# Run oscap command to generate the fix script, we will call it remediation.sh:
#
if [ "${VERBOSE}" == "YES" ]; then
  echo "Creating remediation script."
fi
oscap xccdf generate fix --result-id $RESULTID --output $REMEDIATION_SCRIPT $OSCAP_RESULTS
#
# enable the remediation script to be executable
#
chmod ug+rx,o-x,o+r $REMEDIATION_SCRIPT
#
# Create OVAL report
#
if [ "${VERBOSE}" == "YES" ]; then
  echo
  echo "Creating OVAL report."
fi
oscap oval eval --results $OVAL_RESULTS --report $OVAL_REPORT $OVAL_FILE
#
if [ "${VERBOSE}" == "YES" ]; then
  echo ""
  echo "OSCAP report is located at: $OSCAP_REPORT"
  echo "OVAL report is located at: $OSCAP_REPORT $OVAL_FILE"
  echo "OSCAP remediation script is located at: $REMEDIATION_SCRIPT"
  echo
fi
#
exit
