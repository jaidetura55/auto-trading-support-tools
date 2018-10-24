#!/bin/bash

SQLITE=/usr/bin/sqlite3
DB_FILE=/home/teru/work/optionchan/data/option.db
EXEC_SQLITE="$SQLITE $DB_FILE"

# parse qseter
saveIFS=$IFS
IFS='=&'
qs=($QUERY_STRING)
IFS=$saveIFS

declare -A param
for ((i=0; i<${#qs[@]}; i+=2))
do
    param[${qs[i]}]=${qs[i+1]}
done

if [ -n "${param[ld]}" ]; then
    ld=${param[ld]}
else
    nowd=`date +%Y-%m-%d`
    ld=`echo "SELECT min(last_trading_day) FROM option WHERE last_trading_day >= '$nowd';" | $EXEC_SQLITE`
fi

lu=`echo "SELECT max(updated_at) FROM option;" | $EXEC_SQLITE`


echo "Content-Type: text/plain"
echo ""

echo -e ".separator ,\nSELECT o1.target_price, o1.iv, o2.iv, strftime('%m/%d %H:%M', '$lu') FROM (SELECT target_price, iv FROM option WHERE type=1 AND last_trading_day='$ld' AND updated_at='$lu') o1, (SELECT target_price, iv FROM option WHERE type=2 AND last_trading_day='$ld' AND updated_at='$lu') o2 WHERE o1.target_price = o2.target_price;" | $EXEC_SQLITE
