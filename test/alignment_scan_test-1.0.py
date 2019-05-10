"""Friedrich Schotte, Jan 29, 2016 - Jan 29, 2016"""
from pdb import pm
from logging import warn
try: from rayonix_detector_XPP import ccd
except: warn("rayonix_detector_XPP not available")
from timing_sequence import timing_sequencer
from timing_system import timing_system
from ImageViewer import show_images
from xppdaq import xppdaq # for testing
from CA import caput # for testing
__version__ = "1.0"

import logging
from tempfile import gettempdir
logging.basicConfig(level=logging.DEBUG,format="%(asctime)s: %(message)s",
    filename=gettempdir()+"/lauecollect_debug.log")

nimages = 20
dir = "/reg/neh/operator/xppopr/experiments/xppj1216/Data/Test/Test3/alignment"
filenames = [dir+"/%03d.mccd" % i for i in range(0,nimages)]
image_numbers = range(1,nimages+1)
laser_on = [0]*nimages
ms_on = [0]*nimages
xatt_on = [1]*nimages
npulses = [11]*nimages

def test_FPGA():
    timing_sequencer.inton_sync = 0
    timing_system.image_number.value = 0
    timing_system.pass_number.value = 0
    timing_system.pulses.value = 0
    timing_sequencer.acquire(laser_on=laser_on,ms_on=ms_on,xatt_on=xatt_on,
        npulses=npulses,image_numbers=image_numbers)

def test():
    test_FPGA()
    ccd.acquire_images_triggered(filenames)
    show_images(filenames)

print("test_FPGA()")
print("test()")
