# oscap_oval_reporting

OSCAP/OVAL reporting

## NAME

Security Content Automation Protocol (SCAP) andOpen Vulnerability and Assessment Language (OVAL®) Reporting script. This script will generate the SCAP and OVAL reports to use as a guideline to secure and harden your systems.

This script is currently written to support CentOS 7 only at this time. The script can be modified to accommodate other Linux distributions and releases.


## SYNOPSIS

oscapOvalReporting.sh [OPTION]... [FILE]

## DESCRIPTION

**-d, --destination... [FILE]**

Destination directory for the output reports. Otherwise reports will be created in the current directory.

**-h, --help**

Display this help and exit."

**-s, --spacewalk**

Install Spacewalk OSCAP packages if not installed already.

**-v, --verbose**

Show all output to standard out.
