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
    IN THE SOFTWARE.
*/
module deimos.nanomsg.reqrep;

extern(C):
@system nothrow @nogc:

enum NN_PROTO_REQREP = 3;

enum NN_REQ = NN_PROTO_REQREP * 16 + 0;
enum NN_REP = NN_PROTO_REQREP * 16 + 1;

enum NN_REQ_RESEND_IVL = 1;

union nn_req_handle {
    int i;
    void* ptr;
}

int nn_req_send (int s, nn_req_handle hndl, const(void)* buf, size_t len, int flags);
int nn_req_recv (int s, nn_req_handle* hndl, void* buf, size_t len, int flags);
