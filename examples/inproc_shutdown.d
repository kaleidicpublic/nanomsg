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
import deimos.nanomsg.inproc;

import core.thread;
import core.time;
import core.stdc.errno;

import testutil;
//#include "../src/utils/attr.h"
//#include "../src/utils/thread.c"

/*  Stress test the inproc transport. */

enum THREAD_COUNT = 100;
enum SOCKET_ADDRESS = "inproc://test";

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

int main ()
{
    int sb;
    int i;
    int j;
    Thread[THREAD_COUNT] threads;

    /*  Stress the shutdown algorithm. */

    sb = test_socket (AF_SP, NN_PUB);
    test_bind (sb, SOCKET_ADDRESS);

    for (j = 0; j != 10; ++j) {
        for (i = 0; i != THREAD_COUNT; ++i)
            threads[i] = new Thread({routine(null);}).start;
        for (i = 0; i != THREAD_COUNT; ++i)
            threads[i].join;
    }

    test_close (sb);

    return 0;
}

