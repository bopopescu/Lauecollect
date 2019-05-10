#!/usr/bin/env python
"""Controls for control panels
Author: Friedrich Schotte,
Date created: 2017-10-31
Date last modified: 2018-10-31
"""
__version__ = "1.0" 

from logging import debug,info,warn,error
import wx, wx3_compatibility

class DirectoryControl(wx.Panel):
    """Control panel for SAXS-WAXS Experiments"""
    from persistent_property import persistent_property
    value = persistent_property("value","")
    defaults = persistent_property("defaults",{})
    properties = persistent_property("properties",{})
    refresh_period = persistent_property("refresh_period",1.0)
    
    def __init__(self,parent,name="DirectoryControl",
            locals=None,globals=None,*args,**kwargs):
        self.name = name
        self.locals = locals
        self.globals = globals
        wx.Panel.__init__(self,parent)

        # Controls
        from EditableControls import TextCtrl
        self.control = TextCtrl(self,*args,**kwargs)
        # Needed for wx.Button on MacOS, because Position defaults to 5,3:
        self.control.Position = (0,0) 
        self.control.Enabled = False
        self.button = wx.Button(self,label="Browse...")

        # Layout
        sizer = wx.BoxSizer(wx.HORIZONTAL)
        sizer.Add(self.control,proportion=1)
        sizer.Add(self.button,proportion=0)
        self.Sizer = sizer

        self.Fit()

        # Initialization
        self.initial = {}

        # Callbacks
        self.Bind(wx.EVT_BUTTON,self.OnBrowse,self.button)
        self.Bind(wx.EVT_TEXT_ENTER,self.OnEnter,self.control)
                  
        # Refresh
        from numpy import nan
        self.values = {}
        self.old_values = {}
        self.refreshing = False
        self.executing = False

        from wx.lib.newevent import NewEvent
        self.EVT_THREAD = NewEvent()[1]
        self.Bind(self.EVT_THREAD,self.OnUpdate)
        from threading import Thread
        self.thread = Thread(target=self.keep_updated,name=self.name)
        self.thread.start()

        # Initialization
        self.refresh_status()

    def OnEnter(self,event):
        value = self.control.Value
        info("User requested %s = %r" % (self.name,value))
        if self.value: self.execute("%s = %r" % (self.value,value))
        self.refresh()

    def OnBrowse(self,event):
        pathname = str(self.control.Value)
        from os.path import exists,dirname
        while pathname and not exists(pathname): pathname = dirname(pathname)
        dlg = wx.DirDialog(self,"Choose a directory:",style=wx.DD_DEFAULT_STYLE)
        # ShowModal pops up a dialog box and returns control only after the user
        # has selects OK or Cancel.
        dlg.Path = pathname
        if dlg.ShowModal() == wx.ID_OK:
            from normpath import normpath
            value = normpath(str(dlg.Path))
            if self.value: self.execute("%s = %r" % (self.value,value))
            self.control.Value = value
        dlg.Destroy()

    def execute(self,command):
        if not self.executing:
            from threading import Thread
            self.execute_thread = Thread(target=self.execute_background,
                args=(command,),name=self.name+".execute")
            self.executing = True
            self.execute_thread.start()
                    
    def execute_background(self,command):
        info("%s: executing %r" % (self.name,command))
        try: exec(command,self.locals,self.globals)
        except Exception,msg:
            if command: warn("%s: %s: %s" % (self.name,command,msg))
        event = wx.PyCommandEvent(self.EVT_THREAD.typeId,self.Id)
        # call OnUpdate in GUI thread
        wx.PostEvent(self.EventHandler,event)
        self.executing = False

    def keep_updated(self):
        """Periodically refresh the displayed settings."""
        from time import time,sleep
        while True:
            try:
                t0 = time()
                while time() < t0+self.refresh_period: sleep(0.1)
                if self.Shown:
                    self.update_data()
                    if self.data_changed:
                        ##debug("keep_updated: data_changed")
                        event = wx.PyCommandEvent(self.EVT_THREAD.typeId,self.Id)
                        # call OnUpdate in GUI thread
                        wx.PostEvent(self.EventHandler,event)
            except wx.PyDeadObjectError: break

    def refresh(self):
        """Force update"""
        from threading import Thread
        if not self.refreshing and self.Shown:
            self.refresh_thread = Thread(target=self.refresh_background,
                name=self.name+".refresh")
            self.refreshing = True
            self.refresh_thread.start()

    def refresh_background(self):
        """Force update"""
        self.update_data()
        if self.data_changed: 
            event = wx.PyCommandEvent(self.EVT_THREAD.typeId,self.Id)
            wx.PostEvent(self.EventHandler,event) # call OnUpdate in GUI thread
        self.refreshing = False

    def update_data(self):
        """Retreive status information"""
        from copy import deepcopy
        from numpy import nan
        self.old_values = deepcopy(self.values)
        for prop in self.properties:
            #StartRasterScan.properties = {
            #    "Value": [
            #        (False, "control.scanning == False"),
            #        (True,  "control.scanning == True"),
            #    ],
            #}
            if type(self.properties[prop]) == list:
                if not prop in self.values: self.values[prop] = {}
                for (choice,expr) in self.properties[prop]:
                    try: value = eval(expr,self.locals,self.globals)
                    except Exception,msg:
                        if expr: warn("%s.%s.%s: %s: %s" % (self.name,prop,choice,expr,msg))
                        value = nan
                    self.values[prop][choice] = value
            #Image.properties = {"Image": "control.camera.RGB_array"}
            elif type(self.properties[prop]) == str:
                expr = self.properties[prop]
                try: value = eval(expr,self.locals,self.globals)
                except Exception,msg:
                    if expr: warn("%s.%s: %s: %s" % (self.name,prop,expr,msg))
                    value = nan
                self.values[prop] = value
        if self.value:
            try: value = eval(self.value,self.locals,self.globals)
            except Exception,msg:
                warn("%s: %s: %s" % (self.name,self.value,msg))
                value = nan
            self.values["value"] = value

    @property
    def data_changed(self):
        """Did the last 'update_data' change the data to be plotted?"""
        changed = (self.values != self.old_values)
        return changed

    @property
    def data_changed(self):
        """Did the last 'update_data' change the data to be plotted?"""
        ##changed = (self.values != self.old_values)
        if sorted(self.values.keys()) != sorted(self.old_values.keys()):
            ##debug("%r != %r" % (self.values.keys(),self.old_values.keys()))
            changed = True
        else:
            changed = False
            for a in self.values:
                item_changed = not nan_equal(self.values[a],self.old_values[a])
                ##debug("%r: changed: %r" % (a,item_changed))
                changed = changed or item_changed
        ##debug("data changed: %r" % changed)
        return changed

    def OnUpdate(self,event=None):
        """Periodically refresh the displayed settings."""
        self.refresh_status()

    def refresh_status(self,event=None):
        """Update the controls with current values"""
        ##debug("refresh_status")
        from numpy import isnan
  
        # One-time initialization
        for prop in self.properties.keys():
            if hasattr(self.control,prop):
                if not prop in self.initial:
                    self.initial[prop] = getattr(self.control,prop)
            else: warn("%r has no property %r" % (self.name,prop))

        for prop in self.properties.keys():
            if hasattr(self.control,prop):
                value = self.initial[prop]
                if prop in self.defaults: value = self.defaults[prop]
                if prop in self.values and prop in self.properties:
                    #StartRasterScan.properties = {
                    #    "Value": [
                    #        (False, "control.scanning == False"),
                    #        (True,  "control.scanning == True"),
                    #    ],
                    #}
                    if type(self.properties[prop]) == list:
                        for choice,expr in self.properties[prop]:
                            if choice in self.values[prop] \
                                and not isnan(self.values[prop][choice]) \
                                and self.values[prop][choice]:
                                value = choice
                                break
                    #Image.properties = {"Image": "control.camera.RGB_array"}
                    elif type(self.properties[prop]) == str:
                        value = self.values[prop]
                if prop == "ToolTip": value = wx.ToolTip(value)
                debug("%s.%s=%r" % (type_name(self.control),prop,value))
                if getattr(self.control,prop,None) != value:
                    try: setattr(self.control,prop,value)
                    except Exception,msg:
                        error("%s.%s = %r: %s" % (type_name(self.control),prop,value,msg))
            else: warn("%r has no property %r" % (self.name,prop))

        if self.value:
            prop = "Value"
            if hasattr(self.control,prop):
                value = ""
                if prop in self.initial:  value = self.initial[prop]
                if prop in self.defaults: value = self.defaults[prop]
                if "value" in self.values: value = self.values["value"]
                if prop == "ToolTip": value = wx.ToolTip(value)
                value = self.control_value(value)
                debug("%s.%s=%r" % (type_name(self.control),prop,value))
                if getattr(self.control,prop,None) != value:
                    try: setattr(self.control,prop,value)
                    except Exception,msg:
                        error("%s.%s=%r: %s" % (type_name(self.control),prop,value,msg))
            else: warn("%r has no property %r" % (self.name,prop))

        if self.executing:
            self.control.Label = self.control.Label.strip(".")+"..."

    def control_value(self,value):
        """Convert the value into the form that can be represented by the
        control"""
        from numpy import isnan
        if self.control_data_type == str and not isinstance(value,str):
            if isinstance(value,float) and isnan(value): value = ""
            else:
                if self.scale:
                    try: value = value*self.scale
                    except Exception,msg: error("%r*%r: %s" % (value,self.scale,msg))
                try: value = self.format % value
                except Exception,msg: error("%r % %r: %s" % (self.format,value,msg))
                try: value = str(value)
                except Exception,msg:
                    error("str(%r): %s" % (value,msg))
                    value=""
        if self.control_data_type == bool and not isinstance(value,bool):
            try: value = bool(value)
            except Exception,msg:
                error("bool(%r): %s" % (value,msg))
                value=False
        return value

    @property
    def control_data_type(self):
        """Python data type (str,int,bool) that can be represented by the
        control"""
        type = str
        if isinstance(self.control,wx.ToggleButton): type = bool
        if isinstance(self.control,wx.CheckBox): type = bool
        return type        
        

def type_name(object):
    type_name = repr(type(object))
    # E.g. <class 'wx._controls.ToggleButton'>
    type_name = type_name.strip("<>")
    # E.g. class 'wx._controls.ToggleButton'
    type_name = type_name.replace("class ","")
    # E.g. 'wx._controls.ToggleButton'
    type_name = type_name.strip("'")
    # E.g. wx._controls.ToggleButton
    type_name = type_name.replace("_controls.","")
    # E.g. wx.ToggleButton
    return type_name

def test_eval(expr,locals=None,globals=None):
    return eval(expr,locals,globals)

def test_exec(expr,locals=None,globals=None):
    exec(expr,locals,globals)

def nan_equal(a,b):
    """Are to array equal? a and b may contain NaNs"""
    import numpy
    try: numpy.testing.assert_equal(a,b)
    except AssertionError: return False
    return True


if __name__ == '__main__':
    from pdb import pm
    import logging; from tempfile import gettempdir
    logfile = gettempdir()+"/SAXS_WAXS_Control_Panel.log"
    logging.basicConfig(level=logging.INFO,
        format="%(asctime)s %(levelname)s %(module)s.%(funcName)s, line %(lineno)d: %(message)s",
        ##filename=logfile,
    )
    import autoreload
    from instrumentation import * # passed on in "globals()"
    # Needed to initialize WX library
    wx.app = wx.App(redirect=False)
    frame = wx.Frame(None)
    control = DirectoryControl(frame,globals=globals(),locals=locals(),
        name="Collect_Panel.Path",
        size=(500,-1),
    )
    frame.Fit()
    frame.Show()
    wx.app.MainLoop()
