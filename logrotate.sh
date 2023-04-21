#########################################################################
# File Name: a.sh
# Author: xiezg
# mail: xzghyd2008@hotmail.com
# Created Time: 2023-04-19 15:39:25
# Last modified: 2023-04-21 11:29:50
#########################################################################
#!/bin/sh
set -x

#############
#$1 需要监控轮转的日志文件，该文件是reopen的输出文件
#$2 reopen进程的PID文件，用于通知reopen重新打开该文件
#############

LOCK_FILE=/run/containerd.lock
MAX_FILESIZE=`expr 1024 \* 1024 \* 5`
LOG_FILENAME=$1
REOPEN_PID_PATH=$2

function process_is_running(){

    if [ ! -f "/proc/$1/status" ];then
        echo 0
        return
    fi

    if [ `cat /proc/$1/status | grep -E "^Name:"| awk '{print $2}'` != "$2" ];then
        echo 0
        return
    fi

    echo 1
}

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

while [ `process_is_running \`cat $REOPEN_PID_PATH\` reopen` -eq 0 ]
do
    echo "waiting reopen working"
    sleep 1
done

REOPEN_PID=`cat $REOPEN_PID_PATH`
echo "reopen pid: $REOPEN_PID"

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
