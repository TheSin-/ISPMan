#!/bin/sh

# rm -rf ../../patches
rm $(find ../../patches/* | grep -v CVS)
if [ ! -e ../../patches/ ]; then mkdir ../../patches/; fi

dpatch patch-template -p "10-ispman.conf.diff" "ispman.conf.diff" <ispman.conf.diff > ../../patches/10-ispman.conf.dpatch

dpatch patch-template -p "20-liblocations" "liblocations.diff" <liblocations.diff > ../../patches/20-liblocations.dpatch

# dpatch patch-template -p "30-ldif-prepatch-debian" "ldif-prepatch-debian.diff" <ldif-prepatch-debian.diff > ../../patches/30-ldif-prepatch-debian.dpatch

dpatch patch-template -p "40-slapd.ldapv3.conf" "slapd.ldapv3.conf (example)" <slapd.ldapv3.conf.diff > ../../patches/40-slapd.ldapv3.conf.dpatch

# dpatch patch-template -p "50-vhosts.conf.template" "vhosts.conf.template - extend for vlogger and suexec" <vhosts.conf.template.diff > ../../patches/50-vhosts.conf.template.dpatch

## dpatch patch-template -p "20-" "" < > ../../patches/20-

ls  -1 ../../patches/ |grep dpatch | grep -v 00list > ../../patches/00list


