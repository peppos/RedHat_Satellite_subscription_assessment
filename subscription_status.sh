#!/bin/bash

SAT_USER="admin"
SAT_PASSWORD="password"
SAT_URL="https://satellite.example.com"
TMP_DIR="/tmp"
OUT_DIR="/root"
ORGANIZATION="Example"


assestement ()
{
if [ $1 == "SmartManagement" ]; then
        hammer --csv subscription list --organization $ORGANIZATION --search "Smart Management"  | grep -v "\-1" |grep -v HPC > $TMP_DIR/$1.uuid
else
        hammer --csv subscription list --organization $ORGANIZATION --search "$1" | grep Linux |grep -v Extended | grep -v "\-1" |grep -v HPC > $TMP_DIR/$1.uuid
fi

for i in `cat $TMP_DIR/$1.uuid |awk -F, '{print $2}'`
do
        ID=`cat $TMP_DIR/$1.uuid | grep $i | awk -F, '{print $1}'`
        SUB=`cat $TMP_DIR/$1.uuid | grep $i | awk -F"\"" '{print $2}'`
        TYPE=`cat $TMP_DIR/$1.uuid  | awk -F"\"" '{print $3}' | awk -F, '{print $4}'`
        for x in `su -c "psql -d candlepin -c \"select uuid from cp_consumer where id in (select consumer_id from cp_entitlement where pool_id = '$i' );\"" postgres  | grep -v uuid | grep -v row | grep -v "\---"`
        do
                MODEL=`curl -X GET -s -k -u $SAT_USER:$SAT_PASSWORD $SAT_URL/api/v2/hosts?search="$x" | python -m json.tool  | grep model_name | cut -d':' -f2`
                NAME=`curl -X GET -s -k -u $SAT_USER:$SAT_PASSWORD $SAT_URL/api/v2/hosts?search="$x" | python -m json.tool | grep -A40 content_host_id | grep "\"name\"" | cut -d':' -f2`
                HOST_ID=`curl -X GET -s -k -u $SAT_USER:$SAT_PASSWORD $SAT_URL/api/v2/hosts?search="$x" | python -m json.tool  | grep -A40 content_host_id | grep "\"id\"" | awk '{print $NF}' | cut -d, -f1`
                CPU_SOCKET=`curl -X GET -s -k -u $SAT_USER:$SAT_PASSWORD $SAT_URL/api/hosts/${HOST_ID}/facts?per_page=300| python -m json.tool | grep cpu_socket |awk -F: '{print $NF}' |awk -F\" '{print $2}'`
                echo $ID,$SUB,$TYPE,$x,$MODEL$NAME,$CPU_SOCKET,$HOST_ID >> $OUT_DIR/$1.uuid
        done
done
}


case "$1" in

"Physical")  assestement Physical
    ;;

"Datacenter")  assestement Datacenter
    ;;

"unlimited")  assestement unlimited
    ;;

"Self-support") assestement Self-support
        ;;

"SmartManagement") assestement SmartManagement
        ;;

"all")  assestement unlimited
        assestement Physical
        assestement Datacenter
        assestement Self-support
        cat $TMP_DIR/unlimited.uuid > $OUT_DIR/subscription_consumed
        cat $TMP_DIR/Physical.uuid >> $OUT_DIR/subscription_consumed
        cat $TMP_DIR/Datacenter.uuid >> $OUT_DIR/subscription_consumed
        cat $TMP_DIR/Self-support.uuid >> $OUT_DIR/subscription_consumed
    ;;

*)  echo $"Usage: $0 {Physical|Datacenter|unlimited|Self-support|SmartManagement|all}"
    exit 2

   ;;

esac 
