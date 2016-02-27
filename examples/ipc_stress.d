/*
    Copyright (c) 2012 Martin Sustrik  All rights reserved.
    Copyright 2015 Garrett D'Amore <garrett@damore.org>

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"),
    to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense,
    and/or sell copies of the Software, and to permit persons to whom
    the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
    THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
    IN THE SOFTWARE.
*/



import deimos.nanomsg.nn;
import deimos.nanomsg.pair;
import deimos.nanomsg.pubsub;
import deimos.nanomsg.pipeline;
import deimos.nanomsg.ipc;

import core.thread;
import core.time;
import core.atomic;

import testutil;
//#include "../src/utils/thread.c"
//#include "../src/utils/atomic.h"
//#include "../src/utils/atomic.c"

/*  Stress test the IPC transport. */

enum THREAD_COUNT = 10;
enum TEST_LOOPS = 10;
enum SOCKET_ADDRESS = "ipc://test-stress.ipc";

shared uint active;

static void server(void *arg)
{
    int bytes;
    int sock = nn_socket(AF_SP, NN_PULL);
    assert(sock >= 0);
    assert(nn_bind(sock, SOCKET_ADDRESS) >= 0);
    while (1)
    {
        char *buf = null;
        if (!active) break;
        bytes = nn_recv(sock, &buf, NN_MSG, 0);
        assert(bytes >= 0);
        nn_freemsg(buf);
    }
    nn_close(sock);
}

static void client(void *arg)
{
    int bytes;
    enum msg = "0";
    int sz_msg = msg.length + 1; // '\0' too
    int i;

    for (i = 0; i < TEST_LOOPS; i++) {
        int cli_sock = nn_socket(AF_SP, NN_PUSH);
        assert(cli_sock >= 0);
        assert(nn_connect(cli_sock, SOCKET_ADDRESS) >= 0);
        /*  Give time to allow for connect to establish. */
        Thread.sleep(50.msecs);
        bytes = nn_send(cli_sock, msg.ptr, sz_msg, 0);
        /*  This would better be handled via semaphore or condvar. */
        Thread.sleep(100.msecs);
        assert(bytes == sz_msg);
        nn_close(cli_sock);
    }
    active.atomicOp!"-="(1);
}

int main()
{
    int i;
    int cli_sock;
    int bytes;
    Thread srv_thread;
    Thread[THREAD_COUNT] cli_threads;
    active = THREAD_COUNT;
    /*  Stress the shutdown algorithm. */
    srv_thread = new Thread({server(null);}).start; 

    for (i = 0; i != THREAD_COUNT; ++i)
        cli_threads[i] = new Thread({client(null);}).start; 
    for (i = 0; i != THREAD_COUNT; ++i)
        cli_threads[i].join;

    active = 0;
    cli_sock = nn_socket(AF_SP, NN_PUSH);
    assert(cli_sock >= 0);
    assert(nn_connect(cli_sock, SOCKET_ADDRESS) >= 0);
    bytes = nn_send(cli_sock, &i, i.sizeof, 0);
    assert(bytes == i.sizeof);
    nn_close(cli_sock);
    srv_thread.join;

    return 0;
}

