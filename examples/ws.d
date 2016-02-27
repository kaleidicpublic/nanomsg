/*
    Copyright (c) 2012 250bpm s.r.o.  All rights reserved.
    Copyright (c) 2014 Wirebird Labs LLC.  All rights reserved.
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
import deimos.nanomsg.ws;

import core.thread;
import core.time;
import core.stdc.errno;
import core.stdc.string;

import testutil;

enum SOCKET_ADDRESS = "ws://127.0.0.1:5555";

/*  Basic tests for WebSocket transport. */

/*  test_text() verifies that we drop messages properly when sending invalid
    UTF-8, but not when we send valid data. */
void test_text() {

    int sb;
    int sc;
    int opt;
    ubyte bad[20];

    /*  Negative testing... bad UTF-8 data for text. */
    sb = test_socket (AF_SP, NN_PAIR);
    sc = test_socket (AF_SP, NN_PAIR);

    /*  Wait for connects to establish. */
    Thread.sleep (200.msecs);

    opt = NN_WS_MSG_TYPE_TEXT;
    test_setsockopt(sb, NN_WS, NN_WS_MSG_TYPE, &opt, opt.sizeof);
    opt = NN_WS_MSG_TYPE_TEXT;
    test_setsockopt(sc, NN_WS, NN_WS_MSG_TYPE, &opt, opt.sizeof);
    opt = 500;
    test_setsockopt(sb, NN_SOL_SOCKET, NN_RCVTIMEO, &opt, opt.sizeof);

    test_bind (sb, SOCKET_ADDRESS);
    test_connect (sc, SOCKET_ADDRESS);

    test_send (sc, "GOOD");
    test_recv (sb, "GOOD");

    /*  and the bad ... */
    strcpy(cast(char*)bad, "BAD.");
    bad[2] = cast(char)0xDD;
    test_send (sc, bad);

    /*  Make sure we dropped the frame. */
    test_drop (sb, ETIMEDOUT);
}

int main ()
{
    int rc;
    int sb;
    int sc;
    int opt;
    size_t sz;
    int i;

    /*  Try closing bound but unconnected socket. */
    sb = test_socket (AF_SP, NN_PAIR);
    test_bind (sb, "ws://*:5555");
    test_close (sb);

    /*  Try closing a TCP socket while it not connected. At the same time
        test specifying the local address for the connection. */
    sc = test_socket (AF_SP, NN_PAIR);
    test_connect (sc, "ws://127.0.0.1:5555");
    test_close (sc);

    /*  Open the socket anew. */
    sc = test_socket (AF_SP, NN_PAIR);

    /*  Check socket options. */
    sz = opt.sizeof;
    rc = nn_getsockopt (sc, NN_WS, NN_WS_MSG_TYPE, &opt, &sz);
    assert (rc == 0);
    assert (sz == opt.sizeof);
    assert (opt == NN_WS_MSG_TYPE_BINARY);

version(none)
{
    //opt = 100;
    //sz = opt.sizeof;
    //rc = nn_getsockopt (sc, NN_WS, NN_WS_HANDSHAKE_TIMEOUT, &opt, &sz);
    //assert (rc == 0);
    //assert (sz == opt.sizeof);
    //assert (opt == 100);
}

    /*  Default port 80 should be assumed if not explicitly declared. */
    rc = nn_connect (sc, "ws://127.0.0.1");
    assert (rc >= 0);

    /*  Try using invalid address strings. */
    rc = nn_connect (sc, "ws://*:");
    assert (rc < 0);
    assert (nn_errno () == EINVAL);
    rc = nn_connect (sc, "ws://*:1000000");
    assert (rc < 0);
    assert (nn_errno () == EINVAL);
    rc = nn_connect (sc, "ws://*:some_port");
    assert (rc < 0);
    rc = nn_connect (sc, "ws://eth10000;127.0.0.1:5555");
    assert (rc < 0);
    assert (nn_errno () == ENODEV);

    rc = nn_bind (sc, "ws://127.0.0.1:");
    assert (rc < 0);
    assert (nn_errno () == EINVAL);
    rc = nn_bind (sc, "ws://127.0.0.1:1000000");
    assert (rc < 0);
    assert (nn_errno () == EINVAL);
    rc = nn_bind (sc, "ws://eth10000:5555");
    assert (rc < 0);
    assert (nn_errno () == ENODEV);

    rc = nn_connect (sc, "ws://:5555");
    assert (rc < 0);
    assert (nn_errno () == EINVAL);
    rc = nn_connect (sc, "ws://-hostname:5555");
    assert (rc < 0);
    assert (nn_errno () == EINVAL);
    rc = nn_connect (sc, "ws://abc.123.---.#:5555");
    assert (rc < 0);
    assert (nn_errno () == EINVAL);
    rc = nn_connect (sc, "ws://[::1]:5555");
    assert (rc < 0);
    assert (nn_errno () == EINVAL);
    rc = nn_connect (sc, "ws://abc.123.:5555");
    assert (rc < 0);
    assert (nn_errno () == EINVAL);
    rc = nn_connect (sc, "ws://abc...123:5555");
    assert (rc < 0);
    assert (nn_errno () == EINVAL);
    rc = nn_connect (sc, "ws://.123:5555");
    assert (rc < 0);
    assert (nn_errno () == EINVAL);

    test_close (sc);

    Thread.sleep (200.msecs);

    sb = test_socket (AF_SP, NN_PAIR);
    test_bind (sb, SOCKET_ADDRESS);
    sc = test_socket (AF_SP, NN_PAIR);
    test_connect (sc, SOCKET_ADDRESS);

    /*  Leave enough time for connection establishment. */
    Thread.sleep (200.msecs);

    /*  Ping-pong test. */
    for (i = 0; i != 100; ++i) {

        test_send (sc, "ABC");
        test_recv (sb, "ABC");

        test_send (sb, "DEF");
        test_recv (sc, "DEF");
    }

    /*  Batch transfer test. */
    for (i = 0; i != 100; ++i) {
        test_send (sc, "0123456789012345678901234567890123456789");
    }
    for (i = 0; i != 100; ++i) {
        test_recv (sb, "0123456789012345678901234567890123456789");
    }

    test_close (sc);
    test_close (sb);

    test_text ();

    return 0;
}
