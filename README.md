nanomsg D interface
====================
nanomsg is a socket library that provides several common communication patterns. It aims to make the networking layer fast, scalable, and easy to use. Implemented in C, it works on a wide range of operating systems with no further dependencies.

The communication patterns, also called "scalability protocols", are basic blocks for building distributed systems. By combining them you can create a vast array of distributed applications. The following scalability protocols are currently available:

- PAIR - simple one-to-one communication
- BUS - simple many-to-many communication
- REQREP - allows to build clusters of stateless services to process user requests
- PUBSUB - distributes messages to large sets of interested subscribers
- PIPELINE - aggregates messages from multiple sources and load balances them among many destinations
- SURVEY - allows to query state of multiple applications in a single go

Scalability protocols are layered on top of the transport layer in the network stack. At the moment, the nanomsg library supports the following transports mechanisms:

- INPROC - transport within a process (between threads, modules etc.)
- IPC - transport between processes on a single machine
- TCP - network transport via TCP

The library exposes a BSD-socket-like C API to the applications.

It is licensed under MIT/X11 license.

"nanomsg" is a trademark of Garrett D'Amore

# Usage

```D
import deimos.nanomsg.nn; //main header
import deimos.nanomsg.reqrep; // other heasers
import deimos.nanomsg.inproc;
...
```
