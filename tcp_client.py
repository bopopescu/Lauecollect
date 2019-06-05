#!/usr/bin/env python
"""Simple TCP/IP communication with a server.

Author: Friedrich Schotte
Date created: 2016-11-06
Date last modified: 2019-06-01
"""
__version__ = "1.5.2" # issue: ignoring unexpected reply '\n\n\n' 
from logging import debug,info,warn,error

class tcp_client_object(object):
    name = "tcp_client"
    from persistent_property import persistent_property
    ip_address = persistent_property("ip_address","localhost:2000")

    def __init__(self,name=None):
        if name: self.name = name

    def query(self,command,terminator="\n",count=None):
        """Evaluate a command in the server and return the result.
        """
        from tcp_client import query
        reply = query(self.ip_address,command,terminator,count)
        return reply

    def send(self,command):
        """Evaluate a command in server.
        """
        from tcp_client import send
        send(self.ip_address,command)

    def __repr__(self): return "%s(%r)" % (type(self).__name__,self.name) 

from numpy import nan
def tcp_property(query_string,default_value=nan):
    """A propery object to be used inside a class"""
    def get(self):
        ## Performs a query and returns the result as a number
        value = self.query("self."+query_string)
        dtype = type(default_value)
        try: value = dtype(eval(value))
        except: value = default_value
        return value
    def set(self,value): self.query("self.%s = %r" % (query_string,value))
    return property(get,set)


connections = {}
timeout = 5.0

def send(ip_address_and_port,command):
    """Send a command that does not generate a reply.
    ip_address_and_port: e.g. '164.54.161.34:2001'
    command: string, will by '\n' terminated"""
    query(ip_address_and_port,command,count=0)
write = send

def query(ip_address_and_port,command,terminator="\n",count=None):
    """Send a command that generates a reply.
    ip_address_and_port: e.g. '164.54.161.34:2001'
    command: string, will by '\n' terminated
    count: if given, number of bytes to read as reply, overrides terminator
    Return value: reply
    """
    with lock(ip_address_and_port):
        reply = ""
        if not ip_address_valid(ip_address_and_port): warn("IP address unknown")
        else:
            import socket # for exception
            if not command.endswith("\n"): command += "\n"
            for attempt in range(0,2):
                if attempt > 0: warn("query %.200r, retrying..." % command)
                try: 
                    c = connection(ip_address_and_port)
                    if c is None: break
                    # Clear input queue
                    c.settimeout(1e-6)
                    discard = ""
                    while True:
                        try:
                            discard += c.recv(65536)
                            c.settimeout(0.1)
                        except socket.timeout: break
                    if len(discard) > 0:
                        warn("query %.200r, ignoring unexpected reply %.200r (%d bytes)" %
                            (command,discard[0:80],len(discard)))
                    c.settimeout(3)
                    c.sendall(command)
                    reply = ""
                    if count is not None:
                        disconnected = False
                        while len(reply) < count:
                            r = c.recv(count-len(reply))
                            reply += r
                            if len(r) == 0: disconnected = True; break
                        if len(reply) > count:
                            warn("query %.200r, count=%d: discarding %d bytes" %
                                (command,count,len(reply)-count))
                            reply = reply[0:count]
                        if disconnected: warn("disconnected"); continue
                    elif terminator:
                        while not terminator in reply:
                            r = c.recv(65536)
                            reply += r
                            if len(r) == 0: break
                        if len(r) == 0: warn("disconnected"); continue
                except socket.error,msg:
                    warn("query %.200r, error %s" % (command,msg))
                    if ip_address_and_port in connections:
                        ##debug("resetting connection to %s" % ip_address_and_port)
                        del connections[ip_address_and_port]
                    continue
                break    
            ##if count is not None: debug("query %.200r, count=%d, got %d bytes" % (command,count,len(reply)))
            ##elif terminator: debug("query %.200r, %.23r" % (command,reply))
        return reply

def disconnect(ip_address_and_port):
    """Make sure no connection is open to the specified port.
    ip_address_and_port: e.g. '164.54.161.34:2001'
    """
    with lock(ip_address_and_port):
        if ip_address_and_port in connections:
            ##debug("disconnecting %s" % ip_address_and_port)
            del connections[ip_address_and_port]

def connected(ip_address_and_port):
    """Is server online?
    ip_address_and_port: e.g. '164.54.161.34:2001'
    """
    with lock(ip_address_and_port):
        connected = False
        if not ip_address_valid(ip_address_and_port): warn("IP address unknown")
        else:
            connected = connection(ip_address_and_port) is not None
        return connected

def connection(ip_address_and_port):
    """Cached IP socket connection"""
    connection = None
    if not ip_address_valid(ip_address_and_port): warn("IP address unknown")
    else:
        from thread import start_new_thread
        from time import time,sleep
        
        if not ip_address_and_port in connecting:
            connecting[ip_address_and_port] = False
            
        if not connection_alive(ip_address_and_port):
            if not ip_address_and_port in first_attempt:
                first_attempt[ip_address_and_port] = time()
            if not connecting[ip_address_and_port]:
                connecting[ip_address_and_port] = True
                start_new_thread(connect,(ip_address_and_port,))
            while not connection_alive(ip_address_and_port):
                sleep(0.010)
                if time()-first_attempt[ip_address_and_port] > 1.0: break

        if connection_alive(ip_address_and_port) and ip_address_and_port in connections:
            # reset timeout
            if ip_address_and_port in first_attempt:
                del first_attempt[ip_address_and_port] 
            connection = connections[ip_address_and_port]
        else: connection = None
    return connection

def connect(ip_address_and_port):
    """Establish IP socket connection"""
    import socket
    if not connection_alive(ip_address_and_port):
        if ip_address_and_port in connections:
            warn("tcp client: %s: reconnecting" % ip_address_and_port)
        connection = socket.socket()
        connection.settimeout(timeout)
        request_keep_alive(connection)
        ##debug("tcp client: %s connecting" % ip_address_and_port)
        ip_address,port = ip_address_and_port.split(":")
        port = int(port)
        try: connection.connect((ip_address,port))
        except socket.error,m:
            warn("tcp client: %s: connect: %s" % (ip_address_and_port,m))
            connection = None
        if connection:
            ##debug("tcp client: %s: connected" % ip_address_and_port)
            connection.settimeout(timeout)
            connections[ip_address_and_port] = connection
        elif ip_address_and_port in connections:
            del connections[ip_address_and_port]
    connecting[ip_address_and_port] = False

def ip_address_valid(ip_address_and_port):
    ip_address = ip_address_and_port.split(":")[0]
    valid = (ip_address != "")
    return valid

def request_keep_alive(connection):
    """Request that the OS preriodcally sends "keep alive" packets to check
    whether a TCP connection is still active"""
    import socket
    connection.setsockopt(socket.SOL_SOCKET,socket.SO_KEEPALIVE,1)
    try: # MacOS, Linux?
        TCP_KEEPALIVE = 0x10 # idle time
        TCP_KEEPINTVL = 0x101
        TCP_KEEPCNT = 0x102
        connection.setsockopt(socket.IPPROTO_TCP,TCP_KEEPALIVE,3)
        connection.setsockopt(socket.IPPROTO_TCP,TCP_KEEPINTVL,3)
        connection.setsockopt(socket.IPPROTO_TCP,TCP_KEEPCNT,1)
        ##debug("Linux-style keep_alive request succeeded")
    except: pass
    try: # Windows
        connection.ioctl(socket.SIO_KEEPALIVE_VALS,(1,1000,1000))
        ##debug("Windows-style keep_alive request succeeded")
    except: pass

def connection_alive(ip_address_and_port):
    """Is socket in usable state?"""
    import socket
    
    if not ip_address_and_port in connections: return False
    c = connections[ip_address_and_port]
    
    try: c.getpeername()
    except socket.error,m:
        warn("tcp client: %s alive? peername: %s"%(ip_address_and_port,m));
        return False
    
    timeout = c.gettimeout()
    c.settimeout(0.000001)
    try:
        if len(c.recv(1)) == 0:
           warn("tcp client: %s alive? disconnected"% ip_address_and_port);
           return False
    except socket.timeout: pass
    except socket.error,m:
        warn("tcp client: %s alive? recv: %s"%(ip_address_and_port,m));
        return False
    c.settimeout(timeout)
    try: c.send("")
    except socket.error,m:
        warn("tcp client: %s alive? send: %s"%(ip_address_and_port,m));
        return False
    return True

def lock(ip_address_and_port):
    """A per-connection thread synchronization lock
    ip_address_and_port: e.g. '164.54.161.34:2001'
    """
    from thread import allocate_lock
    if not ip_address_and_port in locks:
        locks[ip_address_and_port] = allocate_lock()
    lock = locks[ip_address_and_port]
    return lock

locks = {}
first_attempt = {}
connecting = {}


if __name__ == "__main__":
    from pdb import pm
    import logging
    logging.basicConfig(level=logging.DEBUG,
        format="%(asctime)s %(levelname)s: %(message)s")
    from time import time
    ip_address_and_port = "pico25.niddk.nih.gov:2002"
    print('connected("localhost:2222")')
    print('connected("mx340hs.cars.aps.anl.gov:2222")')
    print('connected("128.231.5.170:2002")')
    print('connected("pico25.niddk.nih.gov:2002")')
    print('query("pico25.niddk.nih.gov:2002","registers")')
