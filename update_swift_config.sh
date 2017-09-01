#!/bin/bash

set -e

################### Variables Section ##############################
# Add the new variables that you want configured.
swiftauthuser="<new user>"
swiftauthkey="<new keys>"
swifturl="<new auth url>"	# trailing slash is required
swifthost="<new swift host>"
swiftproxyhost="<new host>:443"
#
#### Match the following. Orig_ variables should reflect the existing 
# settings. Matching is used to change them.
orig_swiftauthuser="<old user>"
orig_swiftauthkey="<old key>"
orig_swifturl="<old auth url>"
orig_swiftproxyhost="<old hosts>:443"
#
backupdir="/root/update_swift_backup"

# Keep backups of stuff we change
mkdir -p ${backupdir}

# There is typically one swift accessmethod but let's check.
echo "... Update the swift accessmethod ... "
for x in `storagemgr list acc|grep -w "swift "|awk '{print $1}'`; do
    storagemgr edit acc $x swift -- auth_url=${swifturl} username=${swiftauthuser} \
    password=${swiftauthkey}
done

# Search for all swift_clients and update
echo "... Update swift_client accessmethod ... "
for x in `storagemgr list acc|grep swift_client|awk '{print $1}'`; do 
    storagemgr edit acc $x swift_client -- username=${swiftauthuser} \
    password=${swiftauthkey}
done

# Update swiftnode endpoint
echo "... Update swift endpoint ... "
storagemgr --no-pager edit server swiftnode host=${swifthost} state=A

## Swift LowRes (Proxy) ##

# 5.13+: use secure_link_swift.nginx
# Update nginx secure_link config
echo "... Updating secure_link_swift.nginx ..."
cp -L --backup=numbered /var/ardendo/conf/nginx/common/secure_link_swift.nginx \
${backupdir}/
sed -i -e "s#${orig_swifturl}#${swifturl}#g" \
/var/ardendo/conf/nginx/common/secure_link_swift.nginx
sed -i -e "/X-Auth-Key / s#${orig_swiftauthkey}#${swiftauthkey}#g" \
/var/ardendo/conf/nginx/common/secure_link_swift.nginx
sed -i -e "/X-Auth-User / s#${orig_swiftauthuser}#${swiftauthuser}#g" \
/var/ardendo/conf/nginx/common/secure_link_swift.nginx

# 5.14+: adds swift_upstream.nginx for lowres proxy
echo "... Updating swift_upstream.nginx ..."
cp -L --backup=numbered /var/ardendo/conf/nginx/main/swift_upstream.nginx ${backupdir}/
sed -i -e "s#${orig_swiftproxyhost}#${swiftproxyhost}#g" \
/var/ardendo/conf/nginx/main/swift_upstream.nginx

# Restart nginx 
echo "... Restarting nginx and xfer daemons ... "
/opt/ardome/bin/ardemctl restart xfer,nginx
echo "... nginx start .. just in case ..."
/opt/ardome/bin/ardemctl start nginx

echo "All done!"

#[eof]