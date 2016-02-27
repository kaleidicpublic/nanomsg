 /*
    Copyright (c) 2012 Martin Sustrik  All rights reserved.

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"),
    to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense,
    and/or sell copies of the Software, and to permit persons to whom

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
import deimos.nanomsg.bus;
import deimos.nanomsg.pair;
import deimos.nanomsg.pubsub;
import deimos.nanomsg.reqrep;
import deimos.nanomsg.inproc;

import core.thread;
import core.time;
import core.stdc.errno;

import testutil;

/*  Tests inproc transport. */

enum SOCKET_ADDRESS = "inproc://test";

int main ()
{
    int rc;
    int sb;
    int sc;
    int s1, s2;
    int i;
    char buf [256];
    int val;
     nn_msghdr hdr;
     nn_iovec iovec;
    ubyte body_ [3];
    void *control;
     nn_cmsghdr *cmsg;
    ubyte *data;

    /*  Create a simple topology. */
    sc = test_socket (AF_SP, NN_PAIR);
    test_connect (sc, SOCKET_ADDRESS);
    sb = test_socket (AF_SP, NN_PAIR);
    test_bind (sb, SOCKET_ADDRESS);

    /*  Try a duplicate bind. It should fail. */
    rc = nn_bind (sc, SOCKET_ADDRESS);
    assert (rc < 0 && errno == EADDRINUSE);

    /*  Ping-pong test. */
    for (i = 0; i != 100; ++i) {

        test_send (sc, "ABC");
        test_recv (sb, "ABC");
        test_send (sb, "DEFG");
        test_recv (sc, "DEFG");
    }

    /*  Batch transfer test. */
    for (i = 0; i != 100; ++i) {
        test_send (sc, "XYZ");
    }
    for (i = 0; i != 100; ++i) {
        test_recv (sb, "XYZ");
    }

    test_close (sc);
    test_close (sb);

    /*  Test whether queue limits are observed. */
    sb = test_socket (AF_SP, NN_PAIR);
    val = 200;
    test_setsockopt (sb, NN_SOL_SOCKET, NN_RCVBUF, &val, val.sizeof);
    test_bind (sb, SOCKET_ADDRESS);
    sc = test_socket (AF_SP, NN_PAIR);
    test_connect (sc, SOCKET_ADDRESS);

    val = 200;
    test_setsockopt (sc, NN_SOL_SOCKET, NN_SNDTIMEO, &val, val.sizeof);
    i = 0;
    enum msg = "0123456789";
    while (1) {
        rc = nn_send (sc, msg.ptr, 10, 0);
        if (rc < 0 && nn_errno () == ETIMEDOUT)
            break;
        assert (rc >= 0);
        assert (rc == 10);
        ++i;
    }
    assert (i == 20);
    test_recv (sb, msg);
    test_send (sc, msg);
    rc = nn_send (sc, msg.ptr, 10, 0);
    assert (rc < 0 && nn_errno () == ETIMEDOUT);
    for (i = 0; i != 20; ++i) {
        test_recv (sb, msg);
    }

    /*  Make sure that even a message that doesn't fit into the buffers
        gets across. */
    for (i = 0; i != buf.sizeof; ++i)
        buf [i] = 'A';
    rc = nn_send (sc, buf.ptr, 256, 0);
    assert (rc >= 0);
    assert (rc == 256);
    rc = nn_recv (sb, buf.ptr, buf.sizeof, 0);
    assert (rc >= 0);
    assert (rc == 256);

    test_close (sc);
    test_close (sb);

version(none)
{
    /*  Test whether connection rejection is handled decently. */
    sb = test_socket (AF_SP, NN_PAIR);
    test_bind (sb, SOCKET_ADDRESS);
    s1 = test_socket (AF_SP, NN_PAIR);
    test_connect (s1, SOCKET_ADDRESS);
    s2 = test_socket (AF_SP, NN_PAIR);
    test_connect (s2, SOCKET_ADDRESS);
    Thread.sleep (100.msecs);
    test_close (s2);
    test_close (s1);
    test_close (sb);
}

    /* Check whether SP message header is transferred correctly. */
    sb = test_socket (AF_SP_RAW, NN_REP);
    test_bind (sb, SOCKET_ADDRESS);
    sc = test_socket (AF_SP, NN_REQ);
    test_connect (sc, SOCKET_ADDRESS);

    test_send (sc, "ABC");

    iovec.iov_base = body_.ptr;
    iovec.iov_len = body_.length;
    hdr.msg_iov = &iovec;
    hdr.msg_iovlen = 1;
    hdr.msg_control = &control;
    hdr.msg_controllen = NN_MSG;
    rc = nn_recvmsg (sb, &hdr, 0);
    assert (rc == 3);

    cmsg = NN_CMSG_FIRSTHDR (&hdr);
    while (1) {
        assert (cmsg);
        if (cmsg.cmsg_level == PROTO_SP && cmsg.cmsg_type == SP_HDR)
            break;
        cmsg = NN_CMSG_NXTHDR (&hdr, cmsg);
    }
    assert (cmsg.cmsg_len == NN_CMSG_SPACE (8+size_t.sizeof));
    data = NN_CMSG_DATA (cmsg);
    assert (!(data[0+size_t.sizeof] & 0x80));
    assert (data[4+size_t.sizeof] & 0x80);

    nn_freemsg (control);

    test_close (sc);
    test_close (sb);

    /* Test binding a new socket after originally bound socket shuts down. */
    sb = test_socket (AF_SP, NN_BUS);
    test_bind (sb, SOCKET_ADDRESS);

    sc = test_socket (AF_SP, NN_BUS);
    test_connect (sc, SOCKET_ADDRESS);

    s1 = test_socket (AF_SP, NN_BUS);
    test_connect (s1, SOCKET_ADDRESS);

    /* Close bound socket, leaving connected sockets connect. */
    test_close (sb);

    Thread.sleep (100.msecs);

    /* Rebind a new socket to the address to which our connected sockets are listening. */
    s2 = test_socket (AF_SP, NN_BUS);
    test_bind (s2, SOCKET_ADDRESS);

    /*  Ping-pong test. */
    for (i = 0; i != 100; ++i) {

        test_send (sc, "ABC");
        test_send (s1, "QRS");
        test_recv (s2, "ABC");
        test_recv (s2, "QRS");
        test_send (s2, "DEFG");
        test_recv (sc, "DEFG");
        test_recv (s1, "DEFG");
    }

    /*  Batch transfer test. */
    for (i = 0; i != 100; ++i) {
        test_send (sc, "XYZ");
    }
    for (i = 0; i != 100; ++i) {
        test_recv (s2, "XYZ");
    }
    for (i = 0; i != 100; ++i) {
        test_send (s1, "MNO");
    }
    for (i = 0; i != 100; ++i) {
        test_recv (s2, "MNO");
    }

    test_close (s1);
    test_close (sc);
    test_close (s2);

    return 0;
}

