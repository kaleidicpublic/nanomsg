/*
    Copyright (c) 2012 Martin Sustrik  All rights reserved.
    Copyright (c) 2015 Jack R. Dunaway.  All rights reserved.

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

import core.thread;
import core.stdc.errno;
import testutil;
//#include "../src/utils/attr.h"
//#include "../src/utils/thread.c"
//#include "../src/utils/atomic.c"

/*  Test condition of closing sockets that are blocking in another thread. */

enum TEST_LOOPS = 10;
enum SOCKET_ADDRESS = "tcp://127.0.0.1:5557";

static void routine (void *arg)
{
    int s;
    int rc;
    int msg;

    assert (arg);

    s = *(cast(int*) arg);

    /*  We don't expect to actually receive a message here;
        therefore, the datatype of 'msg' is irrelevant. */
    rc = nn_recv (s, &msg, msg.sizeof, 0);

    assert (nn_errno () == EBADF);
}

int main ()
{
    int sb;
    int i;

    for (i = 0; i != TEST_LOOPS; ++i) {
        sb = test_socket (AF_SP, NN_PULL);
        test_bind (sb, SOCKET_ADDRESS);
        Thread.sleep (100.msecs);
        auto thread = new Thread({routine(&sb);});
        thread.start;
        Thread.sleep (100.msecs);
        test_close (sb);
        thread.join;
    }

    return 0;
}
