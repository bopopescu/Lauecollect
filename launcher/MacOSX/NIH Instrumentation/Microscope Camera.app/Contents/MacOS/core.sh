#!/bin/bash -l
localdir=`dirname "$0"`
dir=`cd "${localdir}/../../../../../.."; pwd`
exec python "$dir/MicroscopeCamera_advanced.py" >> ~/Library/Logs/Python.log 2>&1
