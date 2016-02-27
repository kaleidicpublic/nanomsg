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

import core.thread;
import core.stdc.errno;
import std.conv;

import std.datetime;

import testutil;
//#include "../src/utils/stopwatch.c"

int main ()
{
    int rc;
    int s;
    int timeo;
    char buf [3];
    StopWatch sw;
    Duration elapsed;

    s = test_socket (AF_SP, NN_PAIR);

    timeo = 100;
    rc = nn_setsockopt (s, NN_SOL_SOCKET, NN_RCVTIMEO, &timeo, timeo.sizeof);
    assert (rc == 0);
    sw.start;
    rc = nn_recv (s, buf.ptr, buf.sizeof, 0);
    sw.stop;
    elapsed = to!Duration(sw.peek);
    assert (rc < 0 && nn_errno () == ETIMEDOUT);
    assert (elapsed > ((100000) - 10000).usecs && elapsed < ((100000) + 50000).usecs);

    timeo = 100;
    rc = nn_setsockopt (s, NN_SOL_SOCKET, NN_SNDTIMEO, &timeo, timeo.sizeof);
    assert (rc == 0);
    sw.reset;
    sw.start;
    enum msg = "ABC";
    rc = nn_send (s, msg.ptr, 3, 0);
    sw.stop;
    elapsed = to!Duration(sw.peek);
    assert (rc < 0 && nn_errno () == ETIMEDOUT);
    assert (elapsed > ((100000) - 10000).usecs && elapsed < ((100000) + 50000).usecs);

    test_close (s);

    return 0;
}

