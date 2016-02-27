/*
    Copyright (c) 2012-2014 Martin Sustrik  All rights reserved.
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
    IN THE SOFTWARE.
*/
module deimos.nanomsg.nn;

extern(C):
@system nothrow @nogc:

/******************************************************************************/
/*  ABI versioning support.                                                   */
/******************************************************************************/

/*  Don't change this unless you know exactly what you're doing and have      */
/*  read and understand the following documents:                              */
/*  www.gnu.org/software/libtool/manual/html_node/Libtool-versioning.html     */
/*  www.gnu.org/software/libtool/manual/html_node/Updating-version-info.html  */

/*  The current interface version. */
enum NN_VERSION_CURRENT = 4;

/*  The latest revision of the current interface. */
enum NN_VERSION_REVISION = 0;

/*  How many past interface versions are still supported. */
enum NN_VERSION_AGE = 0;

/******************************************************************************/
/*  Errors.                                                                   */
/******************************************************************************/

/*  A number random enough not to collide with different errno ranges on      */
/*  different OSes. The assumption is that error_t is at least 32-bit type.   */
enum NN_HAUSNUMERO = 156384712;

/*  Native nanomsg error codes.                                               */
enum ETERM = NN_HAUSNUMERO + 53;
enum EFSM = NN_HAUSNUMERO + 54;

/*  This function retrieves the errno as it is known to the library.          */
/*  The goal of this function is to make the code 100% portable, including    */
/*  where the library is compiled with certain CRT library (on Windows) and   */
/*  linked to an application that uses different CRT library.                 */
int nn_errno();

/*  Resolves system errors and native errors to human-readable string.        */
const(char)* nn_strerror (int errnum);


/*  Returns the symbol name (e.g. "NN_REQ") and value at a specified index.   */
/*  If the index is out-of-range, returns null and sets errno to EINVAL       */
/*  General usage is to start at i=0 and iterate until null is returned.      */
const(char)* nn_symbol (int i, int *value);

/*  Constants that are returned in `ns` member of nn_symbol_properties        */
enum NN_NS_NAMESPACE = 0;
enum NN_NS_VERSION = 1;
enum NN_NS_DOMAIN = 2;
enum NN_NS_TRANSPORT = 3;
enum NN_NS_PROTOCOL = 4;
enum NN_NS_OPTION_LEVEL = 5;
enum NN_NS_SOCKET_OPTION = 6;
enum NN_NS_TRANSPORT_OPTION = 7;
enum NN_NS_OPTION_TYPE = 8;
enum NN_NS_OPTION_UNIT = 9;
enum NN_NS_FLAG = 10;
enum NN_NS_ERROR = 11;
enum NN_NS_LIMIT = 12;
enum NN_NS_EVENT = 13;

/*  Constants that are returned in `type` member of nn_symbol_properties      */
enum NN_TYPE_NONE = 0;
enum NN_TYPE_INT = 1;
enum NN_TYPE_STR = 2;

/*  Constants that are returned in the `unit` member of nn_symbol_properties  */
enum NN_UNIT_NONE = 0;
enum NN_UNIT_BYTES = 1;
enum NN_UNIT_MILLISECONDS = 2;
enum NN_UNIT_PRIORITY = 3;
enum NN_UNIT_BOOLEAN = 4;

/*  Structure that is returned from nn_symbol  */
struct nn_symbol_properties {

    /*  The constant value  */
    int value;

    /*  The constant name  */
    const(char)* name;

    /*  The constant namespace, or zero for namespaces themselves */
    int ns;

    /*  The option type for socket option constants  */
    int type;

    /*  The unit for the option value for socket option constants  */
    int unit;
}

/*  Fills in nn_symbol_properties structure and returns it's length           */
/*  If the index is out-of-range, returns 0                                   */
/*  General usage is to start at i=0 and iterate until zero is returned.      */
int nn_symbol_info (int i,
    nn_symbol_properties* buf, int buflen);

/******************************************************************************/
/*  Helper function for shutting down multi-threaded applications.            */
/******************************************************************************/

void nn_term();

/******************************************************************************/
/*  Zero-copy support.                                                        */
/******************************************************************************/

enum size_t NN_MSG = -1;

void* nn_allocmsg (size_t size, int type);
void* nn_reallocmsg (void* msg, size_t size);
int nn_freemsg (void* msg);

/******************************************************************************/
/*  Socket definition.                                                        */
/******************************************************************************/

struct nn_iovec {
    void* iov_base;
    size_t iov_len;
}

struct nn_msghdr {
    nn_iovec *msg_iov;
    int msg_iovlen;
    void* msg_control;
    size_t msg_controllen;
}

struct nn_cmsghdr {
    size_t cmsg_len;
    int cmsg_level;
    int cmsg_type;
}

/*  Internal stuff. Not to be used directly.                                  */
nn_cmsghdr* nn_cmsg_nxthdr_ (
    const (nn_msghdr)* mhdr,
    const (nn_cmsghdr)* cmsg);
alias NN_CMSG_ALIGN_ = (len) => (len + size_t.sizeof - 1) & cast(size_t) ~(size_t.sizeof - 1);

/* POSIX-defined msghdr manipulation. */

alias NN_CMSG_FIRSTHDR = (mhdr) => nn_cmsg_nxthdr_ (cast(nn_msghdr*) mhdr, null);

alias NN_CMSG_NXTHDR = (mhdr, cmsg) => nn_cmsg_nxthdr_ (cast(nn_msghdr*) mhdr, cast(nn_cmsghdr*) cmsg);

alias NN_CMSG_DATA = (cmsg) => cast(ubyte*) ((cast(nn_cmsghdr*) cmsg) + 1);

/* Extensions to POSIX defined by RFC 3542.                                   */

alias NN_CMSG_SPACE = (len) => (NN_CMSG_ALIGN_ (len) + NN_CMSG_ALIGN_ (nn_cmsghdr.sizeof));

alias NN_CMSG_LEN = (len) => (NN_CMSG_ALIGN_ (nn_cmsghdr.sizeof) + (len));

/*  SP address families.                                                      */
enum AF_SP = 1;
enum AF_SP_RAW = 2;

/*  Max size of an SP address.                                                */
enum NN_SOCKADDR_MAX = 128;

/*  Socket option levels: Negative numbers are reserved for transports,
    positive for socket types. */
enum NN_SOL_SOCKET = 0;

/*  Generic socket options (NN_SOL_SOCKET level).                             */
enum NN_LINGER = 1;
enum NN_SNDBUF = 2;
enum NN_RCVBUF = 3;
enum NN_SNDTIMEO = 4;
enum NN_RCVTIMEO = 5;
enum NN_RECONNECT_IVL = 6;
enum NN_RECONNECT_IVL_MAX = 7;
enum NN_SNDPRIO = 8;
enum NN_RCVPRIO = 9;
enum NN_SNDFD = 10;
enum NN_RCVFD = 11;
enum NN_DOMAIN = 12;
enum NN_PROTOCOL = 13;
enum NN_IPV4ONLY = 14;
enum NN_SOCKET_NAME = 15;
enum NN_RCVMAXSIZE = 16;

/*  Send/recv options.                                                        */
enum NN_DONTWAIT = 1;

/*  Ancillary data.                                                           */
enum PROTO_SP = 1;
enum SP_HDR = 1;

int nn_socket (int domain, int protocol);
int nn_close (int s);
int nn_setsockopt (int s, int level, int option, const(void)* optval,
    size_t optvallen);
int nn_getsockopt (int s, int level, int option, void* optval,
    size_t *optvallen);
int nn_bind (int s, const(char)* addr);
int nn_connect (int s, const(char)* addr);
int nn_shutdown (int s, int how);
int nn_send (int s, const(void)* buf, size_t len, int flags);
int nn_recv (int s, void* buf, size_t len, int flags);
int nn_sendmsg (int s, const  nn_msghdr* msghdr, int flags);
int nn_recvmsg (int s, nn_msghdr* msghdr, int flags);

/******************************************************************************/
/*  Socket mutliplexing support.                                              */
/******************************************************************************/

enum NN_POLLIN = 1;
enum NN_POLLOUT = 2;

struct nn_pollfd {
    int fd;
    short events;
    short revents;
}

int nn_poll (nn_pollfd* fds, int nfds, int timeout);

/******************************************************************************/
/*  Built-in support for devices.                                             */
/******************************************************************************/

int nn_device (int s1, int s2);

/******************************************************************************/
/*  Built-in support for multiplexers.                                        */
/******************************************************************************/

int nn_tcpmuxd (int port);
