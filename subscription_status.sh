#!/bin/bash

SAT_USER="admin"
SAT_PASSWORD="password"
SAT_URL="https://satellite_url"
TMP_DIR="/tmp"
OUT_DIR="/your_output_dir"
ORGANIZATION="YOUR_ORG"
DATE=`date +%F--%T`

assestement ()
{
if [ $1 == "SmartManagement" ]; then
        hammer --csv subscription list --organization $ORGANIZATION  --search "Smart Management"  | grep -v "\-1" |grep -v HPC > $TMP_DIR/$1.uuid
else
        hammer --csv subscription list --organization $ORGANIZATION --search "$1" | grep Linux |grep -v Extended | grep -v "\-1" |grep -v HPC > $TMP_DIR/$1.uuid
fi

echo "Product,Subscription,SKU,Model,Hostname,Socket,Socket_ESX,Consumed" > $OUT_DIR/$1.uuid_$DATE
for i in `cat $TMP_DIR/$1.uuid |awk -F, '{print $2}'`
do
        ID=`cat $TMP_DIR/$1.uuid | grep $i | awk -F, '{print $1}'`
        SUB=`cat $TMP_DIR/$1.uuid | grep $i | awk -F"\"" '{print $2}'`
        TYPE=`cat $TMP_DIR/$1.uuid | awk -F"\"" '{print $3}' | awk -F, '{print $4}'`
        for x in `su -c "psql -d candlepin -c \"select uuid from cp_consumer where id in (select consumer_id from cp_entitlement where pool_id = '$i' );\"" postgres  | grep -v uuid | grep -v row | grep -v "\---"`
        do
                MODEL=`curl -X GET -s -k -u $SAT_USER:$SAT_PASSWORD $SAT_URL/api/v2/hosts?search="$x" | python -m json.tool  | grep model_name | cut -d':' -f2`
                NAME=`curl -X GET -s -k -u $SAT_USER:$SAT_PASSWORD $SAT_URL/api/v2/hosts?search="$x" | python -m json.tool | grep -A40 content_host_id | grep "\"name\"" | cut -d':' -f2`
                HOST_ID=`curl -X GET -s -k -u $SAT_USER:$SAT_PASSWORD $SAT_URL/api/v2/hosts?search="$x" | python -m json.tool  | grep -A40 content_host_id | grep "\"id\"" | awk '{print $NF}' | cut -d, -f1`
                CPU_SOCKET=`curl -X GET -s -k -u $SAT_USER:$SAT_PASSWORD $SAT_URL/api/hosts/${HOST_ID}/facts?per_page=300| python -m json.tool | grep cpu_socket |awk -F: '{print $NF}'`
                CPU_SOCKET_ESX=`curl -X GET -s -k -u $SAT_USER:$SAT_PASSWORD $SAT_URL/api/hosts/${HOST_ID}/subscriptions |python -m json.tool| grep -A10 $ID |grep "\"sockets\"" | cut -d':' -f2`
                SUB_CONSUMED=`curl -X GET -s -k -u $SAT_USER:$SAT_PASSWORD $SAT_URL/api/hosts/${HOST_ID}/subscriptions |python -m json.tool| grep -A10 $ID |grep "\"quantity_consumed\"" | cut -d':' -f2`
                SKU_NUMBER=`curl -X GET -s -k -u $SAT_USER:$SAT_PASSWORD $SAT_URL/api/hosts/${HOST_ID}/subscriptions |python -m json.tool| grep -A10 $ID |grep "\"product_id\"" | cut -d':' -f2`
                echo $SUB,$SKU_NUMBER$MODEL$NAME$CPU_SOCKET$CPU_SOCKET_ESX$SUB_CONSUMED >> $OUT_DIR/$1.uuid_$DATE
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
        cat $TMP_DIR/unlimited.uuid > $OUT_DIR/subscription_consumed_$DATE
        cat $TMP_DIR/Physical.uuid >> $OUT_DIR/subscription_consumed_$DATE
        cat $TMP_DIR/Datacenter.uuid >> $OUT_DIR/subscription_consumed_$DATE
        cat $TMP_DIR/Self-support.uuid >> $OUT_DIR/subscription_consumed_$DATE
    ;;

*)  echo $"Usage: $0 {Physical|Datacenter|unlimited|Self-support|SmartManagement|all}"
    exit 2

   ;;

esac
