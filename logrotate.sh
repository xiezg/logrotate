#########################################################################
# File Name: a.sh
# Author: xiezg
# mail: xzghyd2008@hotmail.com
# Created Time: 2023-04-19 15:39:25
# Last modified: 2023-04-20 18:10:41
#########################################################################
#!/bin/sh

set -x

LOCK_FILE=/run/containerd.lock
MAX_FILESIZE=`expr 1024 \* 1024 \* 5`
LOG_FILENAME=$1

while [ `ps l | grep "./reopen -p" | grep -v "grep" | awk '{print $3}' | wc -l ` -eq 0 ]
do
    sleep 1
done

REOPEN_PID=`ps l | grep "./reopen -p" | grep -v "grep" | awk '{print $3}'`

echo "$REOPEN_PID"

function fsize(){
    ls -l $1 | awk '{print $5}'
}

function rotate(){

    oldest_one=""
    count=0
    for item in `ls -rt $LOG_FILENAME.*`
    do
        echo $item
        count=$(( count + 1 ))
        num=${item##*[!0-9]}
        dst="$LOG_FILENAME.$(( num+1 ))"
        mv $item $dst
        if [ -z "$oldest_one" ];then
            oldest_one=$dst
        fi
    done

    echo "oldest_one:$oldest_one"
    mv $LOG_FILENAME $LOG_FILENAME.1
    count=$(( count + 1 ))
    touch $LOG_FILENAME

    echo "REOPEN_PID:$REOPEN_PID"
    if [ -n "$REOPEN_PID" ];then
        kill -10 $REOPEN_PID
        echo "kill -10 $REOPEN_PID result:$?"
    fi

    if [ $count -gt 3 ];then 
        mv $oldest_one /tmp/delete_file_log_  && rm -f /tmp/delete_file_log_
        echo "delete $oldest_one"
    fi
}

(
./flock --verbose -xn 200

if [ $? -ne 0 ];then
    exit 0
fi

cd /tmp/
while true
do
    sleep 5 

    echo "I'm $$"

    if [ ! -f $LOG_FILENAME ];then
        echo "$LOG_FILENAME not exists"
        continue
    fi

    if [ `fsize $LOG_FILENAME` -lt $MAX_FILESIZE ];then
        echo "file size:`fsize $LOG_FILENAME`" 
        continue 
    fi

    rotate

    echo "rotate"
done

)200>>$LOCK_FILE
