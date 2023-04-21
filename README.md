# reopen
1. -p 进程的pid存储文件
2. -o 将读取STDIN_FILENO的输入保存到该文件中，并在接接收到SIGUSR1信号后,重新打开该文件
# logrotate
1. $1 需要监控及轮转的日志文件
2. $2 reopen文件的PID文件

# 使用示例

假设third_exec_xxx为第三方可执行程序，需要将其输出内容保存在 $LOG_FILE_NAME中，并实现该日志文件的轮转

```
LOG_FILENAME=/var/log/third_exec.log
REOPEN_PID=/var/run/reopen.pid

rm -f $REOPEN_PID
third_exec_xxx 2>&1 | ./reopen -p $REOPEN_PID -o $LOG_FILENAME &

./logrotate.sh $LOG_FILENAME $REOPEN_PID 2>&1 >/tmp/logrotate.log &
```
