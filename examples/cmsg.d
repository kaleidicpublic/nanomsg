/*
    Copyright (c) 2014 Martin Sustrik  All rights reserved.
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
import deimos.nanomsg.tcp;
import deimos.nanomsg.reqrep;

import testutil;

enum SOCKET_ADDRESS = "tcp://127.0.0.1:5555";

int main ()
{
    int rc;
    int rep;
    int req;
     nn_msghdr hdr;
     nn_iovec iovec;
    ubyte[3] body_;
    ubyte[256] ctrl;
     nn_cmsghdr *cmsg;
    ubyte *data;
    void *buf;
    
    rep = test_socket (AF_SP_RAW, NN_REP);
    test_bind (rep, SOCKET_ADDRESS);
    req = test_socket (AF_SP, NN_REQ);
    test_connect (req, SOCKET_ADDRESS);

    /* Test ancillary data in static buffer. */

    test_send (req, "ABC");

    iovec.iov_base = body_.ptr;
    iovec.iov_len = body_.length;
    hdr.msg_iov = &iovec;
    hdr.msg_iovlen = 1;
    hdr.msg_control = ctrl.ptr;
    hdr.msg_controllen = ctrl.length;
    rc = nn_recvmsg (rep, &hdr, 0);
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

    rc = nn_sendmsg (rep, &hdr, 0);
    assert (rc == 3);
    test_recv (req, "ABC");

    /* Test ancillary data in dynamically allocated buffer (NN_MSG). */

    test_send (req, "ABC");

    iovec.iov_base = body_.ptr;
    iovec.iov_len = body_.length;
    hdr.msg_iov = &iovec;
    hdr.msg_iovlen = 1;
    hdr.msg_control = &buf;
    hdr.msg_controllen = NN_MSG;
    rc = nn_recvmsg (rep, &hdr, 0);
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

    rc = nn_sendmsg (rep, &hdr, 0);
    assert (rc == 3);
    test_recv (req, "ABC");

    test_close (req);
    test_close (rep);

    return 0;
}
