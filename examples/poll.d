/*
    Copyright (c) 2013 Martin Sustrik  All rights reserved.

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
import deimos.nanomsg.inproc;

import core.thread;
import core.time;

import testutil;
//#include "../src/utils/attr.h"
//#include "../src/utils/thread.c"

version(Posix)
    import core.sys.posix.sys.select;
else
    static assert(0);

/*  Test of polling via NN_SNDFD/NN_RCVFD mechanism. */

enum SOCKET_ADDRESS = "inproc://a";

__gshared int sc;

void routine1 (void *arg)
{
   Thread.sleep (10.msecs);
   test_send (sc, "ABC");
}

void routine2 (void *arg)
{
   Thread.sleep (10.msecs);
   nn_term ();
}

enum NN_IN = 1;
enum NN_OUT = 2;

int getevents (int s, int events, int timeout)
{
    int rc;
    fd_set pollset;
    int rcvfd;
    int sndfd;
    int maxfd;
    size_t fdsz;
     timeval tv;
    int revents;

    maxfd = 0;
    FD_ZERO (&pollset);

    if (events & NN_IN) {
        fdsz = rcvfd.sizeof;
        rc = nn_getsockopt (s, NN_SOL_SOCKET, NN_RCVFD, cast(char*) &rcvfd, &fdsz);
        assert (rc == 0);
        assert (fdsz == rcvfd.sizeof);
        FD_SET (rcvfd, &pollset);
        if (rcvfd + 1 > maxfd)
            maxfd = rcvfd + 1;
    }

    if (events & NN_OUT) {
        fdsz = sndfd.sizeof;
        rc = nn_getsockopt (s, NN_SOL_SOCKET, NN_SNDFD, cast(char*) &sndfd, &fdsz);
        assert (rc == 0);
        assert (fdsz == sndfd.sizeof);
        FD_SET (sndfd, &pollset);
        if (sndfd + 1 > maxfd)
            maxfd = sndfd + 1;
    }

    if (timeout >= 0) {
        tv.tv_sec = timeout / 1000;
        tv.tv_usec = (timeout % 1000) * 1000;
    }

    rc = select (maxfd, &pollset, null, null, timeout < 0 ? null : &tv);
    assert (rc >= 0);
    revents = 0;
    if ((events & NN_IN) && FD_ISSET (rcvfd, &pollset))
        revents |= NN_IN;
    if ((events & NN_OUT) && FD_ISSET (sndfd, &pollset))
        revents |= NN_OUT;
    return revents;
}

int main ()
{
    int rc;
    int sb;
    char[3] buf;

     nn_pollfd pfd [2];

    /* Test nn_poll() function. */
    sb = test_socket (AF_SP, NN_PAIR);
    test_bind (sb, SOCKET_ADDRESS);
    sc = test_socket (AF_SP, NN_PAIR);
    test_connect (sc, SOCKET_ADDRESS);
    test_send (sc, "ABC");
    Thread.sleep (100.msecs);
    pfd [0].fd = sb;
    pfd [0].events = NN_POLLIN | NN_POLLOUT;
    pfd [1].fd = sc;
    pfd [1].events = NN_POLLIN | NN_POLLOUT;
    rc = nn_poll (pfd.ptr, 2, -1);
    assert (rc >= 0);
    assert (rc == 2);
    assert (pfd [0].revents == (NN_POLLIN | NN_POLLOUT));
    assert (pfd [1].revents == NN_POLLOUT);
    test_close (sc);
    test_close (sb);

    /*  Create a simple topology. */
    sb = test_socket (AF_SP, NN_PAIR);
    test_bind (sb, SOCKET_ADDRESS);
    sc = test_socket (AF_SP, NN_PAIR);
    test_connect (sc, SOCKET_ADDRESS);

    /*  Check the initial state of the socket. */
    rc = getevents (sb, NN_IN | NN_OUT, 1000);
    assert (rc == NN_OUT);

    /*  Poll for IN when there's no message available. The call should
        time out. */
    rc = getevents (sb, NN_IN, 10);
    assert (rc == 0);

    /*  Send a message and start polling. This time IN event should be
        signaled. */
    test_send (sc, "ABC");
    rc = getevents (sb, NN_IN, 1000);
    assert (rc == NN_IN);

    /*  Receive the message and make sure that IN is no longer signaled. */
    test_recv (sb, "ABC");
    rc = getevents (sb, NN_IN, 10);
    assert (rc == 0);

    /*  Check signalling from a different thread. */
    auto thread = new Thread({routine1(null);}).start;
    rc = getevents (sb, NN_IN, 1000);
    assert (rc == NN_IN);
    test_recv (sb, "ABC");
    thread.join;

    /*  Check terminating the library from a different thread. */
    thread = new Thread({routine2(null);}).start;
    rc = getevents (sb, NN_IN, 1000);
    assert (rc == NN_IN);
    rc = nn_recv (sb, buf.ptr, buf.sizeof, 0);
    assert (rc < 0 && nn_errno () == ETERM);
    thread.join;

    /*  Clean up. */
    test_close (sc);
    test_close (sb);

    return 0;
}

