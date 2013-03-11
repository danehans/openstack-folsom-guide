#!/bin/sh
#
# Keystone Endpoints
#
# Description: Create Services Endpoints

# Mainly inspired by http://www.hastexo.com/resources/docs/installing-openstack-essex-20121-ubuntu-1204-precise-pangolin
# Written by Martin Gerhard Loschwitz / Hastexo
# Modified by Emilien Macchi / StackOps
#
# Support: openstack@lists.launchpad.net
# License: Apache Software License (ASL) 2.0
#

set -xe 
# MySQL definitions
PSQL_USER=keystone
PSQL_DATABASE=keystone
PSQL_HOST=localhost
PSQL_PASSWORD=password

# Keystone definitions
KEYSTONE_REGION=RegionOne
SERVICE_TOKEN=password
SERVICE_ENDPOINT="http://localhost:35357/v2.0"



# other definitions
MASTER="192.168.1.10"

while getopts "u:D:p:m:K:R:E:S:T:vh" opt; do
  case $opt in
    u)
      PSQL_USER=$OPTARG
      ;;
    D)
      PSQL_DATABASE=$OPTARG
      ;;
    p)
      PSQL_PASSWORD=$OPTARG
      ;;
    m)
      PSQL_HOST=$OPTARG
      ;;
    K)
      MASTER=$OPTARG
      ;;
    R)
      KEYSTONE_REGION=$OPTARG
      ;;
    E)
      export SERVICE_ENDPOINT=$OPTARG
      ;;
    S)
      SWIFT_MASTER=$OPTARG
      ;;
    T)
      export SERVICE_TOKEN=$OPTARG
      ;;
    v)
      set -x
      ;;
    h)
      cat <<EOF
Usage: $0 [-m mysql_hostname] [-u mysql_username] [-D mysql_database] [-p mysql_password]
       [-K keystone_master ] [ -R keystone_region ] [ -E keystone_endpoint_url ] 
       [ -S swift_master ] [ -T keystone_token ]
          
Add -v for verbose mode, -h to display this message.
EOF
      exit 0
      ;;
    \?)
      echo "Unknown option -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument" >&2
      exit 1
      ;;
  esac
done  

if [ -z "$KEYSTONE_REGION" ]; then
  echo "Keystone region not set. Please set with -R option or set KEYSTONE_REGION variable." >&2
  missing_args="true"
fi

if [ -z "$SERVICE_TOKEN" ]; then
  echo "Keystone service token not set. Please set with -T option or set SERVICE_TOKEN variable." >&2
  missing_args="true"
fi

if [ -z "$SERVICE_ENDPOINT" ]; then
  echo "Keystone service endpoint not set. Please set with -E option or set SERVICE_ENDPOINT variable." >&2
  missing_args="true"
fi

if [ -z "$PSQL_PASSWORD" ]; then
  echo "MySQL password not set. Please set with -p option or set PSQL_PASSWORD variable." >&2
  missing_args="true"
fi

if [ -n "$missing_args" ]; then
  exit 1
fi
 
keystone service-create --name nova --type compute --description 'OpenStack Compute Service'
keystone service-create --name cinder --type volume --description 'OpenStack Volume Service'
keystone service-create --name glance --type image --description 'OpenStack Image Service'
keystone service-create --name swift --type object-store --description 'OpenStack Storage Service'
keystone service-create --name keystone --type identity --description 'OpenStack Identity'
keystone service-create --name ec2 --type ec2 --description 'OpenStack EC2 service'
keystone service-create --name quantum --type network --description 'OpenStack Networking service'

create_endpoint () {
  case $1 in
    compute)
    keystone endpoint-create --region $KEYSTONE_REGION --service-id $2 --publicurl 'http://'"$MASTER"':8774/v2/$(tenant_id)s' --adminurl 'http://'"$MASTER"':8774/v2/$(tenant_id)s' --internalurl 'http://'"$MASTER"':8774/v2/$(tenant_id)s'
    ;;
    volume)
    keystone endpoint-create --region $KEYSTONE_REGION --service-id $2 --publicurl 'http://'"$MASTER"':8776/v1/$(tenant_id)s' --adminurl 'http://'"$MASTER"':8776/v1/$(tenant_id)s' --internalurl 'http://'"$MASTER"':8776/v1/$(tenant_id)s'
    ;;
    image)
    keystone endpoint-create --region $KEYSTONE_REGION --service-id $2 --publicurl 'http://'"$MASTER"':9292/v2' --adminurl 'http://'"$MASTER"':9292/v2' --internalurl 'http://'"$MASTER"':9292/v2'
    ;;
    object-store)
    if [ $SWIFT_MASTER ]; then
      keystone endpoint-create --region $KEYSTONE_REGION --service-id $2 --publicurl 'http://'"$SWIFT_MASTER"':8080/v1/AUTH_$(tenant_id)s' --adminurl 'http://'"$SWIFT_MASTER"':8080/v1' --internalurl 'http://'"$SWIFT_MASTER"':8080/v1/AUTH_$(tenant_id)s'
    else
      keystone endpoint-create --region $KEYSTONE_REGION --service-id $2 --publicurl 'http://'"$MASTER"':8080/v1/AUTH_$(tenant_id)s' --adminurl 'http://'"$MASTER"':8080/v1' --internalurl 'http://'"$MASTER"':8080/v1/AUTH_$(tenant_id)s'
    fi
    ;;
    identity)
    keystone endpoint-create --region $KEYSTONE_REGION --service-id $2 --publicurl 'http://'"$MASTER"':5000/v2.0' --adminurl 'http://'"$MASTER"':35357/v2.0' --internalurl 'http://'"$MASTER"':5000/v2.0'
    ;;
    ec2)
    keystone endpoint-create --region $KEYSTONE_REGION --service-id $2 --publicurl 'http://'"$MASTER"':8773/services/Cloud' --adminurl 'http://'"$MASTER"':8773/services/Admin' --internalurl 'http://'"$MASTER"':8773/services/Cloud'
    ;;
    network)
    keystone endpoint-create --region $KEYSTONE_REGION --service-id $2 --publicurl 'http://'"$MASTER"':9696/' --adminurl 'http://'"$MASTER"':9696/' --internalurl 'http://'"$MASTER"':9696/'
    ;;
  esac
}

for i in compute volume image object-store identity ec2 network; do
  id=`psql -tA "host=$PSQL_HOST user=$PSQL_USER password=$PSQL_PASSWORD dbname=$PSQL_DATABASE"  -c "SELECT id FROM service WHERE type='$i';"` || exit 1
  create_endpoint $i $id
done

