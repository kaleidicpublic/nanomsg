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

import testutil;

import core.stdc.string;

enum SOCKET_ADDRESS = "inproc://a";
enum SOCKET_ADDRESS_TCP = "tcp://127.0.0.1:5557";

char[1 << 20] longdata;

int main ()
{
    int rc;
    int sb;
    int sc;
    void* buf1, buf2;
    int i;
     nn_iovec iov;
     nn_msghdr hdr;

    sb = test_socket (AF_SP, NN_PAIR);
    test_bind (sb, SOCKET_ADDRESS);
    sc = test_socket (AF_SP, NN_PAIR);
    test_connect (sc, SOCKET_ADDRESS);

    buf1 = nn_allocmsg (256, 0);
    assert (buf1);
    for (i = 0; i != 256; ++i)
        (cast(ubyte*)buf1) [i] = cast(ubyte) i;
    rc = nn_send (sc, &buf1, NN_MSG, 0);
    assert (rc >= 0);
    assert (rc == 256);

    buf2 = null;
    rc = nn_recv (sb, &buf2, NN_MSG, 0);
    assert (rc >= 0);
    assert (rc == 256);
    assert (buf2);
    for (i = 0; i != 256; ++i)
        assert ((cast(ubyte*)buf1) [i] == cast(ubyte) i);
    rc = nn_freemsg (buf2);
    assert (rc == 0);

    buf1 = nn_allocmsg (256, 0);
    assert (buf1);
    for (i = 0; i != 256; ++i)
        (cast(ubyte*)buf1) [i] = cast(ubyte) i;
    iov.iov_base = &buf1;
    iov.iov_len = NN_MSG;
    memset (&hdr, 0, hdr.sizeof);
    hdr.msg_iov = &iov;
    hdr.msg_iovlen = 1;
    rc = nn_sendmsg (sc, &hdr, 0);
    assert (rc >= 0);
    assert (rc == 256);

    buf2 = null;
    iov.iov_base = &buf2;
    iov.iov_len = NN_MSG;
    memset (&hdr, 0, hdr.sizeof);
    hdr.msg_iov = &iov;
    hdr.msg_iovlen = 1;
    rc = nn_recvmsg (sb, &hdr, 0);
    assert (rc >= 0);
    assert (rc == 256);
    assert (buf2);
    for (i = 0; i != 256; ++i)
        assert ((cast(ubyte*)buf1) [i] == cast(ubyte) i);
    rc = nn_freemsg (buf2);
    assert (rc == 0);

    test_close (sc);
    test_close (sb);

    /*  Test receiving of large message  */

    sb = test_socket (AF_SP, NN_PAIR);
    test_bind (sb, SOCKET_ADDRESS_TCP);
    sc = test_socket (AF_SP, NN_PAIR);
    test_connect (sc, SOCKET_ADDRESS_TCP);

    for (i = 0; i < cast(int) longdata.sizeof; ++i)
        longdata[i] = '0' + (i % 10);
    test_send (sb, longdata);

    rc = nn_recv (sc, &buf2, NN_MSG, 0);
    assert (rc >= 0);
    assert (rc == longdata.length);
    assert (buf2);
    for (i = 0; i < cast(int) longdata.length; ++i)
        assert ((cast(char*)buf2) [i] == longdata [i]);
    rc = nn_freemsg (buf2);
    assert (rc == 0);

    test_close (sc);
    test_close (sb);

    return 0;
}
