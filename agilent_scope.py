from __future__ import with_statement
"""
This is to communicate with an Agilent Windows-based oscilloscope over Ethernet.
This version required a server program named "alinemt_scope_server.py" running
on the Oscilloscope computer.

Friedrich Schotte, 6 Sep 2007 - 13 May 2015
"""

import socket # needed for socket.error
from thread import allocate_lock

__version__ = "2.1.1"

NaN = 1e1000/1e1000 # generates Not A Number

class agilent_scope(object):
  "This is to communicate with an Agilent Windows-based oscilloscope over Ethernet."
  def __init__(self,ip_address):
    """ip_address may be given as address:port. If :port is omitted, port
    number 2000 is assumed."""
    self.timeout = 2.0
    if ip_address.find(":") >= 0:
      self.ip_address = ip_address.split(":")[0]
      self.port = int(ip_address.split(":")[1])
    else: self.ip_address = ip_address; self.port = 2000
    self.connection = None
    # This is to make the query method multi-thread safe.
    self.lock = allocate_lock()
    self.retries = 2 # used in case of communation error

  def __repr__(self):
    return "agilent_scope('"+self.ip_address+":"+str(self.port)+"')"

  def write(self,command):
    """Sends a command to the oscilloscope that does not generate a reply,
    e.g. ":CDISplay" """
    if len(command) == 0 or command[-1] != "\n": command += "\n"
    with self.lock: # Allow only one thread at a time inside this function.
      for attempt in range(0,self.retries):
        try:
          if self.connection == None:
            self.connection = socket.socket()
            self.connection.settimeout(self.timeout)
            self.connection.connect((self.ip_address,self.port))
          self.connection.sendall (command)
          return
        except Exception,message:
          if attempt > 0 or self.retries == 1:
            self.log("write %r attempt %d/%d failed: %s" % \
                (command,attempt+1,self.retries,message))
            self.connection = None

  def query(self,command):
    """To send a command that generates a reply, e.g. "InstrumentID.Value".
    Returns the reply"""
    if len(command) == 0 or command[-1] != "\n": command += "\n"
    with self.lock: # Allow only one thread at a time inside this function.
      for attempt in range(0,self.retries):
        try:
          if self.connection == None:
            self.connection = socket.socket()
            self.connection.settimeout(self.timeout)
            self.connection.connect((self.ip_address,self.port))
          self.connection.sendall (command)
          reply = self.connection.recv(4096)
          while reply.find("\n") == -1:
            reply += self.connection.recv(4096)
          if reply.rstrip("\n") != "": return reply.rstrip("\n")
          if attempt > 0 or self.retries == 1:
            self.log("query %r attempt %d/%d generated reply %r" %
              (command,attempt+1,self.retries,reply))
        except Exception,message:
          if attempt > 0 or self.retries == 1:
            self.log("query %r attempt %d/%d failed: %s" %
                (command,attempt+1,self.retries,message))
          self.connection = None
      return ""

  class measurement_object(object):
    """Implements automatic measurements, including averaging and statistics"""

    def __init__(self,scope,n=1,type="value"):
      """n=1,2...6 is the waveform parameter number.
      The parameter is defined from the "Measure" menu, e.g. DeltaTime(2-3).
      The optional 'type' can by "value","min","max","stdev",or "count".
      """
      self.scope = scope; self.n = n; self.type = type
      
    def __repr__(self):
      return repr(self.scope)+".measurement("+str(self.n)+")."+self.type
    
    def get_value(self):
      if self.type == "value": return self.float_result(1)
      if self.type == "average": return self.float_result(4)
      if self.type == "min": return self.float_result(2)
      if self.type == "max": return self.float_result(3)
      if self.type == "stdev": return self.float_result(5)
      if self.type == "count": return self.int_result(6)
      return nan
    value = property(get_value,doc="last sample (without averaging)")

    def get_average(self):
      if self.type == "value": return self.float_result(4)
      if self.type == "average": return self.float_result(4)
      if self.type == "min": return self.float_result(2)
      if self.type == "max": return self.float_result(3)
      if self.type == "stdev": return self.float_result(5)
      if self.type == "count": return self.int_result(6)
      return nan
    average = property(get_average,doc="averaged value")

    def get_min(self): return self.float_result(2)
    min = property(get_min,doc="minimum value contributing to average")

    def get_max(self): return self.float_result(3)
    max = property(get_max,doc="maximum value contributing to average")

    def get_stdev(self): return self.float_result(5)
    stdev = property(get_stdev,doc="standard deviation of individuals sample")

    def get_count(self): return self.int_result(6)
    count = property(get_count,doc="number of measurements averaged")

    def get_name(self): 
      try: return self.result(0)+"."+self.type
      except ValueError: return "?."+self.type
    name = property(get_name,doc="string representation of the measurment")

    def result(self,index):
      """Reads the measurment results from the oscillscope and extracts one
      value. index 0=name,1=current,2=min,3=max,4=mean,5=stdev,6=count"""
      reply = self.scope.query (":MEASure:RESults?")
      # format <name>,<current>,<min>,<max>,<mean>,<stdev>,<count>[,<name>,...]
      fields = reply.split(",")
      i = (self.n-1)*7 + index
      if i < len(fields): return fields[i]

    def float_result(self,index):
      """Reads the measurment results from the oscillscope and extracts one
      value as floating point number.
      index 1=current,2=min,3=max,4=mean,5=stdev"""
      x = self.result(index)
      if x == None: return NaN
      if x == '9.99999E+37': return NaN
      try: return float(x)
      except ValueError: return NaN      

    def int_result(self,index):
      """Reads the measurment results from the oscillscope and extracts one
      value as floating point number.
      index 1=current,2=min,3=max,4=mean,5=stdev"""
      x = self.result(index)
      if x == None: return NaN
      if x == '9.99999E+37': return NaN
      try: return int(float(x))
      except ValueError: return NaN
      
    def start(self): self.scope.start()
    
    def stop(self): self.scope.stop()

    def get_time_range(self): return self.scope.time_range
    def set_time_range(self,value): self.scope.time_range = value
    time_range = property(get_time_range,set_time_range,
      doc="horizontal scale min to max (10 div) in seconds")

  def measurement(self,*args,**kws):
    return agilent_scope.measurement_object(self,*args,**kws)

  def start(self):
    """Clear the accumulated average and restart averaging.
    Also re-eneables the trigger in case the scope was stopped."""
    self.write (":CDISplay")
    self.write (":RUN")
  def stop(self):
    "Freezes the averaging by disabling the trigger of the oscilloscope."
    self.write (":STOP")

  def get_time_range(self):
    try: return float(self.query(":TIMebase:RANGe?"))
    except ValueError: return NaN
  def set_time_range(self,value): self.write (":TIMebase:RANGe %g" % value)
  time_range = property(get_time_range,set_time_range,
    doc="horizontal scale min to max (10 div) in seconds")

  def get_sampling_rate(self):
    "samples per second"
    try: return float(self.query(":ACQuire:SRATe?"))
    except ValueError: return NaN
  sampling_rate = property(get_sampling_rate)

  def get_id(self): return self.query("*IDN?")
  id = property(get_id,doc="Model and serial number")

  class gated_measurement(object):
    """Common code base for gates measurements.
    The Agilent does not support gating on automated measurements.
    Gated mesurements are implemented by downloading the waveform and processing
    it in client computer memory. The gate is determined  by the current position
    of the two vertical cursors on the oscilloscope screen.
    """
    def __init__(self,scope,channel=1): 
      self.scope = scope; self.channel = channel

    def tstart(self): return float(self.scope.query(":MARKer:TSTArt?"))
    def tstop(self):  return float(self.scope.query(":MARKer:TSTOp?"))

    def get_begin(self): return min(self.tstart(),self.tstop())
    def set_begin(self,value): self.scope.write(":MARKer:TSTArt "+str(value))
    begin = property(get_begin,set_begin,doc="starting time of integration gate")

    def get_end(self): return max(self.tstart(),self.tstop())
    def set_end(self,val): self.scope.write(":MARKer:TSTOp "+str(val))
    end = property(get_end,set_end,doc="ending time of integration gate")

    def tstr(t):
      "Convert time given in seconds in more readble format such as ps, ns, ms, s"
      try: t=float(t)
      except: return "?"
      if t != t: return "?" # not a number
      if t == 0: return "0"
      if abs(t) < 1E-20: return "0"
      if abs(t) < 999e-12: return "%.3gps" % (t*1e12)
      if abs(t) < 999e-9: return "%.3gns" % (t*1e9)
      if abs(t) < 999e-6: return "%.3gus" % (t*1e6)
      if abs(t) < 999e-3: return "%.3gms" % (t*1e3)
      return "%.3gs" % t
    tstr = staticmethod(tstr)

  class gated_integral_object(gated_measurement):
    """The Agilent does not support gating on automated measurements.
    The "Area" measurement integrates the whole displayed waveform.
    Gated integration is implemented by downloading the waveform and processing
    it in client computer memory. The integration gate with is determined 
    by the current position of the two vertical cursors on the oscilloscope
    screen.
    """
    def __init__(self,scope,channel=1):
      agilent_scope.gated_measurement.__init__(self,scope,channel)
      self.unit = "Vs"
    def get_value(self):
      return integral(self.scope.waveform(self.channel),self.begin,self.end)
    value = property(get_value,doc="gated integral of waveform")

    def get_name(self):
      return "int("+str(self.channel)+","+self.tstr(self.begin)+","+self.tstr(self.end)+")"
    name = property(get_name,doc="short description")

  def gated_integral(self,channel=1):
    "Area of waveform between vertical markers"
    return agilent_scope.gated_integral_object(self,channel)

  class gated_average_object(gated_measurement):
    """Calculates the average of the part of a waveform, enclosed by the two
    vertical cursors on the oscilloscope screen."""
    def __init__(self,scope,channel=1):
      agilent_scope.gated_measurement.__init__(self,scope,channel)
      self.unit = "V"
    def get_value(self):
      return average(self.scope.waveform(self.channel),self.begin,self.end)
    value = property(get_value,doc="gated average of waveform")

    def get_name(self):
      return "ave("+str(self.channel)+","+self.tstr(self.begin)+","+self.tstr(self.end)+")"
    name = property(get_name,doc="short description")

  def gated_average(self,channel=1):
    "Area of waveform between vertical markers"
    return agilent_scope.gated_average_object(self,channel)

  def waveform(self,channel=1): return self.waveform_16bit(channel)

  def waveform_ascii(self,channel=1):
    "Downloads waveform data in the form of a list of (t,y) tuples"
    self.write(":SYSTEM:HEADER OFF") 
    self.write(":WAVEFORM:SOURCE CHANNEL"+str(channel))
    self.write(":WAVEFORM:FORMAT ASCII")
    data = self.query(":WAVeform:DATA?")
    # format: <value>,<value>,...  example: 5.09E-03,-5.16E-03,...
    y = data.split(",")
    preamble = self.query(":WAVeform:PREAMBLE?")
    xincr = float(preamble.split(",")[4])
    xorig = float(preamble.split(",")[5])
    waveform = []
    for i in range(len(y)): waveform.append((xorig+i*xincr,float(y[i])))
    return waveform

  def waveform_8bit (self,channel=1):
    """Downloads waveform data in the form of a list of (t,y) tuples.
    In contrast to the "waveform" method, this implementation downloads
    binary data, not formatted ASCII text, which is faster. (0.0037 s vs 0.120 s
    for 20 kSamples)"""
    self.write(":SYSTEM:HEADER OFF") 
    self.write(":WAVEFORM:SOURCE CHANNEL"+str(channel))
    self.write(":WAVEFORM:FORMAT BYTE")
    data = self.query(":WAVeform:DATA?")
    # format: #<n><length><binary data>
    # example: #520003...
    n = int(data[1:2]) # number of bytes in "length" block
    length = int(data[2:2+n]) # number of bytes in waveform data to follow
    payload = len(data)-(2+n)
    if length > payload:
      print "(Waveform truncated from",length,"to",payload,"bytes)"
      length = payload
    from struct import unpack
    bytes = unpack("%db" % length,data[2+n:2+n+length])
    preamble = self.query(":WAVeform:PREAMBLE?")
    xincr = float(preamble.split(",")[4])
    xorig = float(preamble.split(",")[5])
    yincr = float(preamble.split(",")[7])
    yorig = float(preamble.split(",")[8])
    waveform = []
    for i in range(length): 
      waveform.append((xorig+i*xincr,yorig+bytes[i]*yincr))
    return waveform

  def waveform_16bit (self,channel=1):
    """Downloads waveform data in the form of a list of (t,y) tuples.
    In contrast to the "waveform" method, this implementation downloads
    binary data, not formatted ASCII text, which is faster. (0.0056 s vs 0.120 s
    for 20 kSamples)"""
    self.write(":SYSTEM:HEADER OFF") 
    self.write(":WAVeform:SOURce CHANNEL"+str(channel))
    self.write(":WAVeform:FORMat WORD")
    self.write(":WAVeform:BYTeorder LSBFirst")
    data = self.query(":WAVeform:DATA?")
    # format: #<n><length><binary data>
    # example: #520003...
    n = int(data[1:2]) # number of bytes in "length" block
    length = int(data[2:2+n]) # number of bytes in waveform data to follow
    payload = (len(data)-(2+n))
    if length > payload:
      print "(Waveform truncated from",length,"to",payload,"bytes)"
      length = payload
    nsamples = length/2
    from struct import unpack
    bytes = unpack("%dh" % nsamples,data[2+n:2+n+nsamples*2])
    preamble = self.query(":WAVeform:PREAMBLE?")
    xincr = float(preamble.split(",")[4])
    xorig = float(preamble.split(",")[5])
    yincr = float(preamble.split(",")[7])
    yorig = float(preamble.split(",")[8])
    waveform = []
    for i in range(nsamples): 
      waveform.append((xorig+i*xincr,yorig+bytes[i]*yincr))
    return waveform

  def log(self,message):
    "Append a message to the log file /tmp/agilent_scope.log"
    from tempfile import gettempdir
    from time import strftime
    from sys import stderr
    if len(message) == 0 or message[-1] != "\n": message += "\n"
    timestamped_message = timestamp()+": "+message
    stderr.write(timestamped_message)
    logfile = gettempdir()+"/agilent_scope.log"
    try: file(logfile,"a").write(timestamped_message)
    except IOError: pass


def timestamp():
    """Current date and time as formatted ASCCI text, precise to 1 ms"""
    from datetime import datetime
    timestamp = str(datetime.now())
    return timestamp[:-3] # omit microsconds

def integral(waveform,begin=-1e1000,end=+1e1000):
  sum = 0
  for i in range(len(waveform)-1):
    if waveform[i][0] >= begin and waveform[i][0] <= end: 
      sum += waveform[i][1]*(waveform[i+1][0]-waveform[i][0])
  if len(waveform) > 1:
    i = len(waveform)-1
    if waveform[i][0] >= begin and waveform[i][0] <= end: 
      sum += waveform[i][1]*(waveform[i][0]-waveform[i-1][0])
  return sum

def average(waveform,begin=-1e1000,end=+1e1000):
  sum = 0; n = 0
  for i in range(len(waveform)):
    if waveform[i][0] >= begin and waveform[i][0] <= end:
      sum += waveform[i][1]; n += 1
  if n>0: return sum/n

def save_waveform(waveform,filename):
  output = file(filename,"w")
  for i in range(len(waveform)):
    output.write(str(waveform[i][0])+"\t"+str(waveform[i][1])+"\n")
  
if __name__ == "__main__": # for testing, remove when done
  from pdb import pm
  id14b_scope = agilent_scope("id14b-scope.cars.aps.anl.gov")
  self = id14b_scope # for debugging
