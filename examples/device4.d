/*
    Copyright (c) 2012 Martin Sustrik  All rights reserved.
    Copyright (c) 2013 GoPivotal, Inc.  All rights reserved.
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
import deimos.nanomsg.reqrep;
import deimos.nanomsg.tcp;

import core.thread;
import core.time;
import core.stdc.errno;

import testutil;
//#include "../src/utils/attr.h"
//#include "../src/utils/thread.c"

enum SOCKET_ADDRESS_F = "tcp://127.0.0.1:5565";
enum SOCKET_ADDRESS_G = "tcp://127.0.0.1:5566";

void device4 (void *arg)
{
    int rc;
    int devf;
    int devg;

    /*  Intialise the device sockets. */
    devf = test_socket (AF_SP_RAW, NN_REP);
    test_bind (devf, SOCKET_ADDRESS_F);
    devg = test_socket (AF_SP_RAW, NN_REQ);
    test_bind (devg, SOCKET_ADDRESS_G);

    /*  Run the device. */
    rc = nn_device (devf, devg);
    assert (rc < 0 && (nn_errno () == ETERM || nn_errno () == EBADF));

    /*  Clean up. */
    test_close (devg);
    test_close (devf);
}

int main ()
{
    int endf;
    int endg;

    /*  Test the bi-directional device with REQ/REP (headers). */

    /*  Start the device. */
    auto thread4 = new Thread({device4(null);}).start;

    /*  Create two sockets to connect to the device. */
    endf = test_socket (AF_SP, NN_REQ);
    test_connect (endf, SOCKET_ADDRESS_F);
    endg = test_socket (AF_SP, NN_REP);
    test_connect (endg, SOCKET_ADDRESS_G);

    /*  Wait for TCP to establish. */
    Thread.sleep (100.msecs);

    /*  Pass a message between endpoints. */
    test_send (endf, "XYZ");
    test_recv (endg, "XYZ");

    /*  Now send a reply. */
    test_send (endg, "REPLYXYZ");
    test_recv (endf, "REPLYXYZ");

    /*  Clean up. */
    test_close (endg);
    test_close (endf);

    /*  Shut down the devices. */
    nn_term ();
    thread4.join;

    return 0;
}
