/*
    Copyright (c) 2012 Martin Sustrik  All rights reserved.

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
import deimos.nanomsg.tcp;

import core.sys.posix.signal;
import core.stdc.errno;

import core.thread;
import core.time;
import core.atomic;

import testutil;
//#include "../src/utils/attr.h"
//#include "../src/utils/thread.c"
//#include "../src/utils/atomic.c"

/*  Stress test the TCP transport. */

enum THREAD_COUNT = 100;
enum TEST2_THREAD_COUNT = 10;
enum MESSAGES_PER_THREAD = 10;
enum TEST_LOOPS = 10;
enum SOCKET_ADDRESS = "tcp://127.0.0.1:5557";

shared uint active;

static void routine (void *arg)
{
    int s;

    s = nn_socket (AF_SP, NN_SUB);
    if (s < 0 && nn_errno () == EMFILE)
        return;
    assert (s >= 0);
    test_connect (s, SOCKET_ADDRESS);
    test_close (s);
}

static void routine2 (void *arg)
{
    int s;
    int i;
    int ms;

    s = test_socket (AF_SP, NN_PULL);

    for (i = 0; i < 10; ++i) {
        test_connect (s, SOCKET_ADDRESS);
    }

    ms = 2000;
    test_setsockopt (s, NN_SOL_SOCKET, NN_RCVTIMEO, &ms, ms.sizeof);

    for (i = 0; i < MESSAGES_PER_THREAD; ++i) {
        test_recv (s, "hello");
    }

    test_close (s);
    active.atomicOp!"-="(1);
}

int main ()
{
    int sb;
    int i;
    int j;
    Thread[THREAD_COUNT] threads;

    /*  Stress the shutdown algorithm. */

    signal (SIGPIPE, SIG_IGN);

    sb = test_socket (AF_SP, NN_PUB);
    test_bind (sb, SOCKET_ADDRESS);

    for (j = 0; j != TEST_LOOPS; ++j) {
        for (i = 0; i != THREAD_COUNT; ++i)
            threads[i] = new Thread({routine(null);}).start;
        for (i = 0; i != THREAD_COUNT; ++i) {
            threads[i].join;
	}
    }

    test_close (sb);

    /*  Test race condition of sending message while socket shutting down  */

    sb = test_socket (AF_SP, NN_PUSH);
    test_bind (sb, SOCKET_ADDRESS);

    for (j = 0; j != TEST_LOOPS; ++j) {
	int ms;
        for (i = 0; i != TEST2_THREAD_COUNT; ++i)
            threads[i] = new Thread({routine2(null);}).start;
        active = TEST2_THREAD_COUNT;

	ms = 2000;
	test_setsockopt (sb, NN_SOL_SOCKET, NN_SNDTIMEO, &ms, ms.sizeof);
        while (active) {
            enum msg = "hello";
            nn_send (sb, msg.ptr, 5, NN_DONTWAIT);
        }

        for (i = 0; i != TEST2_THREAD_COUNT; ++i)
            threads[i].join;
    }

    test_close (sb);

    return 0;
}
