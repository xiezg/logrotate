/*************************************************************************
 # File Name: reopen.c
 # Author: xiezg
 # Mail: xzghyd2008@hotmail.com 
 # Created Time: 2023-04-21 09:46:01
 # Last modified: 2023-04-21 09:49:24
 ************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <getopt.h>
#include <ctype.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <signal.h>

#define FATATL( str, ... )\
    printf( str"\n", ##__VA_ARGS__);\
    sync();\
    exit(1)

char log_fpath[1024];
char pid_fpath[1024];

int flags_reopen = 0;

void sigint_handler (int sig) {
    flags_reopen = 1;
}

void record_pid(){
    char buf[16];
    int fd = open( pid_fpath, O_RDWR|O_TRUNC|O_CREAT, 0644 );

    if( fd == -1 ){
        FATATL( "open pid file:[%s] fails", log_fpath);
    }

    snprintf( buf, 16, "%d", getpid() );

    write( fd, buf, strlen(buf) );
    close( fd);
}

int main(int argc, char *argv[]) {

    int opt;
    int digit_optind = 0;
    char read_buf[1024];
    const char *p;
    int fd_log = -1;

    //捕获SIGUSR1信号，用于标识重新打开logfile
    signal( SIGUSR1, sigint_handler);

    struct option long_options[] = {
        {"output", required_argument, NULL, 'o'},
        {"pid", required_argument, NULL, 'p'},
        {NULL, 0, NULL, 0}
    };

    while ((opt = getopt_long(argc, argv, "o:p:", long_options, &digit_optind)) != -1) {
        switch (opt) {
            case 'o':
                strncpy( log_fpath, optarg, 1024 );
                break;
            case 'p':
                strncpy( pid_fpath, optarg, 1024 );
                break;
            case '?':
                break;
            default:
                printf("Unknown option: %c\n", opt);
                exit(1);
        }
    }

    if( strlen(pid_fpath) > 0 )
        record_pid();

REOPEN:

    if( fd_log != -1 ){
        close( fd_log );
        fd_log = -1;
    }

    if( ( fd_log = open( log_fpath, O_RDWR|O_TRUNC|O_CREAT, 0644 ) ) == -1 ){
        FATATL( "open logfile:[%s] fails.\n", log_fpath );
    }

    while(1){
        ssize_t nrecv = read( STDIN_FILENO, read_buf, 1024 );

        if( nrecv == -1 ){
            FATATL( "read from STDIN fails" );
        }

        if( nrecv == 0 ){
            FATATL( "stdin pipe close" );
        }

        p = read_buf;
        while( nrecv > 0){
            ssize_t nwrite = write( fd_log, p, nrecv );
            if( nwrite == -1 ){
                FATATL( "write logfile fails" );
            }
            p += nwrite;
            nrecv -= nwrite;
        }

        if( flags_reopen ){
            flags_reopen = 0;
            goto REOPEN;
        }
    }

    return 0;
}

