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

import core.thread;
import core.time;

import testutil;

import core.stdc.string;

enum SOCKET_ADDRESS = "inproc://a";

int main ()
{
    int rc;
    int sb;
    int sc;
    nn_iovec[2] iov;
    nn_msghdr hdr;
    char[6] buf;

    sb = test_socket (AF_SP, NN_PAIR);
    test_bind (sb, SOCKET_ADDRESS);
    sc = test_socket (AF_SP, NN_PAIR);
    test_connect (sc, SOCKET_ADDRESS);

    shared static const msg1 = "AB";
    shared static const msg2 = "CDEF";
    shared static const msg3 = "ABCDEF";

    iov [0].iov_base = cast(void*) msg1.ptr;
    iov [0].iov_len = 2;
    iov [1].iov_base = cast(void*) msg2.ptr;
    iov [1].iov_len = 4;
    memset (&hdr, 0, hdr.sizeof);
    hdr.msg_iov = iov.ptr;
    hdr.msg_iovlen = 2;
    rc = nn_sendmsg (sc, &hdr, 0);
    assert (rc >= 0);
    assert (rc == 6);

    iov [0].iov_base = buf.ptr;
    iov [0].iov_len = 4;
    iov [1].iov_base = buf.ptr + 4;
    iov [1].iov_len = 2;
    memset (&hdr, 0, hdr.sizeof);
    hdr.msg_iov = iov.ptr;
    hdr.msg_iovlen = 2;
    rc = nn_recvmsg (sb, &hdr, 0);
    assert (rc >= 0);
    assert (rc == 6);
    assert (memcmp (buf.ptr, msg3.ptr, 6) == 0);

    test_close (sc);
    test_close (sb);

    return 0;
}

