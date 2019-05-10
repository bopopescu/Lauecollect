' ------------------------------------------------ 
' --------------- Synchronize.ab -----------------
' ------------------------------------------------ 
'
' Bit 0 of port 1 on Axis X is read every 500 us.
' When HIGH, a pulse is generated on bit 0 of DOUT.
' After 20 ms, resume reading bit 0 every 500 us.
' 
' Note: 
' A free-running While Loop is capable of looping
' every ~50 us. The STARTSYNC -1 command throttles 
' down the CPU demand down by an order of magnitude
' without compromising the ability to detect trigger
' pulses.
'
DOUT:0::1, 0:0
STARTSYNC-1' -1 sets period to 500 us 
WHILE 1
IF DIN:0::( 1,0)THEN
DOUT:0::1, 0:1
DOUT:0::1, 0:0
STARTSYNC 20
'Insert code here (must execute in <20ms)
 SYNC
STARTSYNC-1
SYNC
END IF
WEND
