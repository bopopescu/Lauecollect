' This program operates the LCLS combined X-ray shutter and attenuator

' Version 1.5.1
' Author: Friedrich Schotte, 12 Oct 2013 - 14 Jan 2016 

' When the level of input "close/open" is TTL high the shutter in open position.
' If it is low in closed or attenuated position.
' When level "full/atten." input is TTL high the attenuator is inserted.
' Otherwise, it is in closed position.
' Input "close/open" high overrides input "full/atten." high.

' Setup: 
' FPGA X-ray shut. -> Breakout box, Digital input 1 -> Ensemble X Opto-In Pin 3
' FPGA X-ray att.  -> Breakout box, Digital input 2 -> Ensemble X Opto-In Pin 4

 PROGRAM 
DIM open_pos,closed_pos,attenuated_pos AS DOUBLE
DIM open_close_speed AS DOUBLE
DIM bits AS INTEGER' axis status bits
DIM home_cyle_complete AS INTEGER' axis status bits
DIM current_pos AS INTEGER
DIM open_level,att_level AS INTEGER' digital input states

SETPARM 6: DefaultRampRate, 500000 ' in deg/s2
attenuated_pos=56
closed_pos=63' normal closed position in open/close mode in deg
open_pos=70' in deg
' Timing for open/close mode
open_close_speed=7200' top speed in deg/s

FAULTACK 6' Make sure fault state is cleared
ENABLE 6' turn the drive on

' With and incremental encoder, after power on, in order for the controller
' to know the absolute angle of the motor it needs to find the "reference" mark 
' of the encoder. The HOME command rotates the motor until the the marker input
' open_level goes high, then stops there and resets the encoder accumulator count to
' zero.
' The program check first if a home run has already been performed, and does
' it only if it has not been done before.
bits=AXISSTATUS(6)
home_cyle_complete=(bits >> 1) BAND 1
IF home_cyle_complete=0 THEN
HOME 6
END IF

WAIT MODE NOWAIT ' Set wait mode to no wait.
ABS' use absolute positioning mode in LINEAR command
RAMP MODE DIST ' Set acceleration/deceleration mode to distance based.

' Start the loop for repetitive motion.
WHILE 1
' Read digital inputs (on AUX I/O connector)
open_level=DIN:0::( 1,1)'Close/open input (0 = closed, 1 = open)
 att_level=DIN:0::( 1,2)'Annuator input (0 = closed, 1 = attenuated)

current_pos=PCMD(6)
IF open_level=1 THEN
IF current_pos<>open_pos THEN
LINEAR 6:open_pos @open_close_speed 
END IF
ELSEIF att_level=1 THEN
IF current_pos<>attenuated_pos THEN
LINEAR 6:attenuated_pos @open_close_speed 
END IF
ELSE
IF current_pos<>closed_pos THEN
LINEAR 6:closed_pos @open_close_speed 
END IF
END IF

WEND
END PROGRAM 
