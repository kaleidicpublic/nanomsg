/*
    Copyright (c) 2013 Insollo Entertainment, LLC. All rights reserved.
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

@system nothrow:

import deimos.nanomsg.nn;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import core.stdc.errno;

import std.string;

extern(C)
{
    @nogc:
    void nn_err_abort();
    int nn_err_errno();
    const(char)* nn_err_strerror(int errnum);
}

static int test_socket(
    int family, int protocol, string file = __FILE__, int line = __LINE__)
{
    int sock;

    sock = nn_socket (family, protocol);
    if (sock == -1) {
        fprintf (stderr, "Failed create socket: %s [%d] (%s:%d)\n",
            nn_err_strerror (errno),
            cast(int) errno, file.ptr, line);
        nn_err_abort ();
    }

    return sock;
}

static int test_connect(
    int sock, string address, string file = __FILE__, int line = __LINE__)
{
    int rc;

    rc = nn_connect (sock, address.toStringz);
    if(rc < 0) {
        fprintf (stderr, "Failed connect to \"%s\": %s [%d] (%s:%d)\n",
            address.toStringz,
            nn_err_strerror (errno),
            cast(int) errno, file.ptr, line);
        nn_err_abort ();
    }
    return rc;
}

static int test_bind(
    int sock, string address, string file = __FILE__, int line = __LINE__)
{
    int rc;

    rc = nn_bind (sock, address.toStringz);
    if(rc < 0) {
        fprintf (stderr, "Failed bind to \"%s\": %s [%d] (%s:%d)\n",
            address.toStringz,
            nn_err_strerror (errno),
            cast(int) errno, file.ptr, line);
        nn_err_abort ();
    }
    return rc;
}

static int test_setsockopt(
    int sock, int level, int option, const void *optval, size_t optlen, string file = __FILE__, int line = __LINE__)
{
    int rc;

    rc = nn_setsockopt (sock, level, option, optval, optlen);
    if(rc < 0) {
        fprintf (stderr, "Failed set option \"%d\": %s [%d] (%s:%d)\n",
            option,
            nn_err_strerror (errno),
            cast(int) errno, file.ptr, line);
        nn_err_abort ();
    }
    return rc;
}

static void test_close(
    int sock, string file = __FILE__, int line = __LINE__)
{
    int rc;

    rc = nn_close (sock);
    if ((rc != 0) && (errno != EBADF && errno != ETERM)) {
        fprintf (stderr, "Failed to close socket: %s [%d] (%s:%d)\n",
            nn_err_strerror (errno),
            cast(int) errno, file.ptr, line);
        nn_err_abort ();
    }
}

static void test_send(
    int sock, const(void)[] data, string file = __FILE__, int line = __LINE__)
{
    size_t data_len;
    int rc;

    data_len = data.length;

    rc = nn_send (sock, data.ptr, data_len, 0);
    if (rc < 0) {
        fprintf (stderr, "Failed to send: %s [%d] (%s:%d)\n",
            nn_err_strerror (errno),
            cast(int) errno, file.ptr, line);
        nn_err_abort ();
    }
    if (rc != cast(int)data_len) {
        fprintf (stderr, "Data to send is truncated: %d != %d (%s:%d)\n",
            rc, cast(int) data_len,
            file.ptr, line);
        nn_err_abort ();
    }
}

static void test_recv(
    int sock, const(void)[] data, string file = __FILE__, int line = __LINE__)
{
    size_t data_len;
    int rc;
    char *buf;

    data_len = data.length;
    /*  We allocate plus one byte so that we are sure that message received
        has correct length and not truncated  */
    buf = cast(char*) malloc (data_len+1);
    assert (buf);

    rc = nn_recv (sock, buf, data_len+1, 0);
    if (rc < 0) {
        fprintf (stderr, "Failed to recv: %s [%d] (%s:%d)\n",
            nn_err_strerror (errno),
            cast(int) errno, file.ptr, line);
        nn_err_abort ();
    }
    if (rc != cast(int)data_len) {
        fprintf (stderr, "Received data has wrong length: %d != %d (%s:%d)\n",
            rc, cast(int) data_len,
            file.ptr, line);
        nn_err_abort ();
    }
    if (memcmp (data.ptr, buf, data_len) != 0) {
        /*  We don't print the data as it may have binary garbage  */
        fprintf (stderr, "Received data is wrong (%s:%d)\n", file.ptr, line);
        nn_err_abort ();
    }

    free (buf);
}

static void test_drop(
    int sock, int err, string file = __FILE__, int line = __LINE__)
{
    int rc;
    char buf[1024];

    rc = nn_recv (sock, buf.ptr, buf.sizeof, 0);
    if (rc < 0 && err != errno) {
        fprintf (stderr, "Got wrong err to recv: %s [%d != %d] (%s:%d)\n",
            nn_err_strerror (errno),
            cast(int) errno, err, file.ptr, line);
        nn_err_abort ();
    } else if (rc >= 0) {
        fprintf (stderr, "Did not drop message: [%d bytes] (%s:%d)\n",
            rc, file.ptr, line);
        nn_err_abort ();
    }
}
