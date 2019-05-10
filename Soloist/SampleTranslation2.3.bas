' This program is to tranlate the sample for a WAXS experiment
' synchronously to an exteranl trigger signal.
' The maximum trigger needed rate is 82 Hz, the translation step 150 um.
' The tranlations is trigger by a rising edge at the digital input 0.

' Friedrich Schotte, NIH, 30 Sep 2008 - 22 Oct 2012

HEADER
INCLUDE "StringLibHeader.basi"
'DEFINE Ethernet 2 'COM channel 2 = Ethernet Socket 1
'The parameter InetSock1Flags needs to be 0x1 (TCP server)
'The port number is given by the parameter InetSock1Port (default: 8000)
END HEADER

DECLARATIONS
GLOBAL Version AS STRING="2.3"
GLOBAL res AS DOUBLE'encoder resolution in mm
 GLOBAL stepsize AS DOUBLE'increment for triggered motion (um)
 GLOBAL start_pos AS DOUBLE'turning point for triggered motion (um)
 GLOBAL end_pos AS DOUBLE'turning point for triggered motion (um)
 GLOBAL auto_return AS INTEGER'automatically return to start at end of travel
 GLOBAL auto_reverse AS INTEGER'automatically reverse direction at end of travel
 GLOBAL speed AS DOUBLE'top speed in um/s
 GLOBAL step_acceleration AS DOUBLE'for triggered operation in um/s2
 GLOBAL acceleration AS DOUBLE'for non-triggered motion in um/s2
 GLOBAL low_limit AS DOUBLE'limit switch trigger point (um)
 GLOBAL high_limit AS DOUBLE'limit switch trigger point (um)
 GLOBAL trigger_enabled AS INTEGER'move stage on external trigger
 GLOBAL timer_enabled AS INTEGER'move stage on a timer  
 GLOBAL timer_period AS DOUBLE'timer period on ms  
 GLOBAL last_level AS INTEGER'digital input state
 GLOBAL trigger_count AS INTEGER'number of trigger events detected
 GLOBAL step_count AS INTEGER'number of triggered steps operations
 GLOBAL trigged_step AS INTEGER'Was last move done on external trigger?
 GLOBAL Command AS STRING'command buffer needed by Handle_Ethernet()
END DECLARATIONS

 PROGRAM
'Initialize global variables
 res=0.001'encoder resolution in mm
 stepsize=-240'increment for triggered motion (um)
 start_pos=-11800'turning point for triggered motion (um)
 end_pos=11960'turning point for triggered motion (um)
 auto_return=1'automatically return to start at end of travel
 auto_reverse=0'automatically reverse direction at end of travel
 trigger_enabled=0'move stage on external trigger
 timer_enabled=0'move stage on a timer  
 timer_period=24'timer period in ms  
 speed=1000000'top speed in um/s
 low_limit=-12600'limit switch trigger point (um)
 high_limit=13470'limit switch trigger point (um)
 step_acceleration=GETPARM(0:AccelDecelRate) 'for triggered operation in um/s2
acceleration=1372800'for non-triggered motion in um/s2 (0.25 s for full stroke)
 trigger_count=0'number of trigger events detected
 step_count=0'number of triggered steps operations
 triggered_step=0'Was last move done on external trigger?
 CALL Restore_Parameters()

DIM direct as INTEGER=1'direction of next move 1 = forward, -1 = backward
 DIM current_pos as DOUBLE
DIM level AS INTEGER'digital input state
 DIM bits AS INTEGER'status bits
 DIM HL AS INTEGER,LL AS INTEGER,moving AS INTEGER'high limit, low limit
 DIM t AS INTEGER'time in milliseconds
 DIM do_step AS INTEGER'Start motion?
'DIM msg as STRING 'for diagnostic messages

' With and incremental encoder, after power on, in order for the controller
' to know the absolute angle of the motor it needs to find the "reference" mark 
' of the encoder. The HOME command rotates the motor until the the marker input
' level goes high, then stops there and resets the encoder accumulator count to
' zero.
' The program check first if a home run has already been performed, and does
' it only if it has not been done before.
DIM HOMED AS INTEGER
bits=AXISSTATUS(0)
HOMED=(bits>>1) BAND 1
IF NOT HOMED THEN
FAULTACK 0 'Make sure fault state is cleared.
ENABLE 0 'Turn the drive on.
HOME 0 'Find the home switch and set encoder count to 0.
DISABLE 0 'Turn the drive off.
END IF

WAIT MODE NOWAIT 'After a motion command, do not wait for it to complete.
RAMP MODE RATE'The acceation ramp is determind by the RAMP RATE parameter (default)

FAULTACK 0 'Make sure any fault state is cleared.

' Go to the starting position using the normal acceleration rate.
'ENABLE 'turn the drive on
'RAMP RATE acceleration
'MOVEABS D end_pos F speed ' Start at positive end of stroke.

'If this is an Autorun program, you must provide time for the Ethernet code to start.
'DWELL 5 
 OPENCOM 2

' Read digital inputs (on AUX I/O connector)
last_level=DIN(1,0)

WHILE 1
do_step=0
IF trigger_enabled THEN
' Read digital inputs (on AUX I/O connector)
level=DIN(1,0)
IF level=1 AND last_level=0 THEN do_step=1 END IF
IF do_step THEN trigger_count=trigger_count+1 END IF
last_level=level
END IF
IF timer_enabled THEN
t=TIMER()
IF t>=timer_period THEN do_step=1 END IF
IF do_step THEN CLEARTIMER END IF
END IF
' On the rising edge of input 1, operated the stage momentarily advancing
' one step forward or backward.
IF do_step THEN
bits=AXISSTATUS(0)
moving=(bits>>3) BAND 1
' Ignore trigger if still busy performing the last motion,
' unless the last motion was externally triggered.
IF NOT moving or triggered_step THEN
current_pos=PCMD(0)
IF end_pos>start_pos THEN HP=end_pos ELSE HP=start_pos END IF
IF end_pos>start_pos THEN LP=start_pos ELSE LP=end_pos END IF
HL=(bits>>22) BAND 1
LL=(bits>>23) BAND 1
FAULTACK 0 'Make sure any fault state is cleared.
ENABLE 0 'turn the drive on
' Optionally, return to start at end of travel.
IF auto_return THEN
IF stepsize>0 AND current_pos+stepsize>HP+1 OR HL THEN
RAMP RATE acceleration
MOVEABS 0:LP:speed ' D position in um, F in um/s
triggered_step=0
step_count=step_count+1
ELSEIF stepsize<0 AND current_pos+stepsize<LP-1 OR LL THEN
RAMP RATE acceleration
MOVEABS 0:HP:speed ' D position in um, F in um/s
triggered_step=0
step_count=step_count+1
ELSE
RAMP RATE step_acceleration
MOVEABS 0:current_pos+stepsize:speed ' D position in um, F in um/s
triggered_step=1
step_count=step_count+1
END IF
' Optionally, reverse direction at end of travel.
ELSEIF auto_reverse THEN
IF current_pos+stepsize>HP OR HL THEN
stepsize=-1*ABS(stepsize)
ELSEIF current_pos+stepsize<LP OR LL THEN
stepsize=ABS(stepsize)
END IF
RAMP RATE step_acceleration
MOVEABS 0:current_pos+stepsize:speed ' D position in um, F in um/s
triggered_step=1
step_count=step_count+1
' Respect soft and hard limits when running on external trigger.
ELSEIF(stepsize>0 AND current_pos+stepsize<=HP AND NOT HL)OR
(stepsize<0 AND current_pos+stepsize>=LP AND NOT LL)THEN
RAMP RATE step_acceleration
MOVEABS 0:current_pos+stepsize:speed ' D position in um, F in um/s
triggered_step=1
step_count=step_count+1
END IF
END IF
END IF

CALL Handle_Ethernet()
WEND
END PROGRAM

' Store some parameters in non-volatile memory.
FUNCTION Save_Parameters()
SETPARM 0:UserInteger1:start_pos 
SETPARM 0:UserInteger2:end_pos 
SETPARM 0:UserDouble1:stepsize 
SAVEPARAMETERS
END FUNCTION

' Reload some parameters from non-volatile memory.
FUNCTION Restore_Parameters()
start_pos=GETPARM(0:UserInteger1) 
end_pos=GETPARM(0:UserInteger2) 
stepsize=GETPARM(0:UserDouble1) 
END FUNCTION

'This procedure performs procedure performs the TCP/IP server communications
'with a remote client.
'Overhead for calling this procedure: 166 us
 FUNCTION Handle_Ethernet()
DIM received AS STRING(80),reply AS STRING(256),parameter AS STRING
DIM nbytes AS INTEGER,n AS INTEGER,offset AS INTEGER
DIM str AS STRING
DIM pos AS DOUBLE,bits AS INTEGER,old_value AS DOUBLE
DIM GO_TO_ AS STRING="GO TO "
DIM TIMER_PERIOD_IS_ AS STRING="TIMER PERIOD IS "
DIM STEP_SIZE_IS_ AS STRING="STEP SIZE IS "
DIM LIMIT_TRAVEL_FROM_ AS STRING="LIMIT TRAVEL FROM "
DIM START_POSITION_ AS STRING="START POSITION "
DIM END_POSITION_ AS STRING="END POSITION "
DIM TO_ AS STRING=" TO "
DIM TOP_SPEED_ AS STRING="TOP SPEED "
DIM ACCELERATION_ AS STRING="ACCELERATION "
DIM ACCELERATION_IN_TRIGGERED_MODE_ AS STRING="ACCELERATION IN TRIGGERED MODE "
DIM SET_THE_LOW_LIMIT_TO_ AS STRING="SET THE LOW LIMIT TO "
DIM SET_THE_HIGH_LIMIT_TO_ AS STRING="SET THE HIGH LIMIT TO "
DIM TRIGGER_COUNT_ AS STRING="TRIGGER COUNT "
DIM STEP_COUNT_ AS STRING="STEP COUNT "
DIM MSG AS STRING'for debugging

nbytes=READCOMCOUNT(2)'Wait until data is received.

IF nbytes>0 THEN
READCOM 2,received,nbytes
CALL ConcatStrToStr(Command,received,Command)

n=LEN(Command)
IF n>0 THEN
IF Command(n-1)="\n"THEN
Command(n-1)=0'Remove trailing newline character.
 CALL ToUpperStr(Command)'Convert everything to upper case
 n=LEN(Command)
IF n>0 THEN'Remove trailing period.
 IF Command(n-1)="."THEN
Command(n-1)=0
END IF
END IF

IF Command="IS THE STAGE MOVING?"THEN
bits=AXISSTATUS(0)
IF(bits>>3) BAND 1THEN
WRITECOM 2,"The stage is moving.\n"
ELSE
WRITECOM 2,"The stage is not moving.\n"
END IF
ELSEIF Command="CURRENT POSITION?"THEN
pos=PFBK(0)
FORMAT reply,"Current position is %g mm.\n",DBLV:res*pos
WRITECOM 2,reply
ELSEIF FindStrInStr(GO_TO_,Command)=0 THEN
offset=LEN(GO_TO_)
CALL ExtractStrFromStr(Command,parameter,offset,LEN(Command)-offset)
pos=CDBL(parameter)/res
FAULTACK 0 'Clear fault status (if present).
ENABLE 0 'Turn on drive (if off).
WAIT MODE NOWAIT 
RAMP RATE acceleration
MOVEABS 0:pos:speed 
triggered_step=0
pos=PCMD(0)
FORMAT reply,"Command position is %g mm.\n",DBLV:res*pos
WRITECOM 2,reply
ELSEIF Command="COMMAND POSITION?"THEN
pos=PCMD(0)
FORMAT reply,"Command position is %g mm.\n",DBLV:res*pos
WRITECOM 2,reply
ELSEIF Command="IS TRIGGER ENABLED?"THEN
IF trigger_enabled THEN
WRITECOM 2,"Trigger is enabled.\n"
ELSE
WRITECOM 2,"Trigger is disabled.\n"
END IF
ELSEIF Command="ENABLE TRIGGER"THEN
FAULTACK 0 'Clear fault status (if present).
ENABLE 0 'Turn on drive (if off).		  
trigger_enabled=1
WRITECOM 2,"Trigger is enabled.\n"
ELSEIF Command="DISABLE TRIGGER"THEN
trigger_enabled=0
WRITECOM 2,"Trigger is disabled.\n"
ELSEIF Command="IS TIMER ENABLED?"THEN
IF timer_enabled THEN
WRITECOM 2,"Timer is enabled.\n"
ELSE
WRITECOM 2,"Timer is disabled.\n"
END IF
ELSEIF Command="ENABLE TIMER"THEN
FAULTACK 0 'Clear fault status (if present).
ENABLE 0 'Turn on drive (if off).		  
timer_enabled=1
WRITECOM 2,"Timer is enabled.\n"
ELSEIF Command="DISABLE TIMER"THEN
timer_enabled=0
WRITECOM 2,"Timer is disabled.\n"
ELSEIF Command="TIMER PERIOD?"THEN
FORMAT reply,"Timer period is %g.\n",DBLV:timer_period*0.001
WRITECOM 2,reply
ELSEIF FindStrInStr(TIMER_PERIOD_IS_,Command)=0 THEN
offset=LEN(TIMER_PERIOD_IS_)
CALL ExtractStrFromStr(Command,parameter,offset,LEN(Command)-offset)
timer_period=CDBL(parameter)/0.001
FORMAT reply,"Timer period is %g.\n",DBLV:timer_period*0.001
WRITECOM 2,reply
ELSEIF Command="STEP SIZE?"THEN
FORMAT reply,"Step size is %g.\n",DBLV:stepsize*res
WRITECOM 2,reply
ELSEIF FindStrInStr(STEP_SIZE_IS_,Command)=0 THEN
old_value=stepsize
offset=LEN(STEP_SIZE_IS_)
CALL ExtractStrFromStr(Command,parameter,offset,LEN(Command)-offset)
stepsize=CDBL(parameter)/res
'if stepsize <> old_value THEN CALL Save_Parameters() END IF
 FORMAT reply,"Step size is %g.\n",DBLV:stepsize*res
WRITECOM 2,reply
ELSEIF Command="CALIBRATE THE STAGE"THEN
'This drives the stage to the home switch coming from 
'the low limit (as specified by the parameter HomeType
'= 0x1) and sets the encoder count to 0 at the point the 
'home switch is triggered. 
'The HOME command will block execution unit completed.
'WAIT MODE NOWAIT does not effect the HOME command.
FAULTACK 0 'Clear fault status (if present).
ENABLE 0 'turn on drive (if off)
HOME 0 
 WRITECOM 2,"Calibrating the stage.\n"
ELSEIF Command="IS THE STAGE CALIBRATED?"THEN
'Check if a home run has already been performed.
 bits=AXISSTATUS(0)
IF(bits>>1) BAND 1THEN
WRITECOM 2,"The stage is calibrated.\n"
ELSE
WRITECOM 2,"The stage is not calibrated.\n"
END IF
ELSEIF Command="IS THE STAGE AT HIGH LIMIT?"THEN
bits=AXISSTATUS(0)
IF(bits>>22) BAND 1THEN
WRITECOM 2,"The stage is at high limit.\n"
ELSE
WRITECOM 2,"The stage is not at high limit.\n"
END IF
ELSEIF Command="IS THE STAGE AT LOW LIMIT?"THEN
bits=AXISSTATUS(0)
IF(bits>>23) BAND 1THEN
WRITECOM 2,"The stage is at low limit.\n"
ELSE
WRITECOM 2,"The stage is not at low limit.\n"
END IF
ELSEIF Command="DOES THE STAGE CHANGE DIRECTION AT TRAVEL LIMITS?"THEN
IF auto_reverse THEN
WRITECOM 2,"The stage changes direction at travel limits.\n"
ELSE
WRITECOM 2,"The stage does not change direction.\n"
END IF
ELSEIF Command="CHANGE DIRECTION AT TRAVEL LIMITS"THEN
auto_reverse=1
auto_return=0
WRITECOM 2,"The stage changes direction at travel limits.\n"
ELSEIF Command="DO NOT CHANGE DIRECTION"THEN
auto_reverse=0
WRITECOM 2,"The stage does not change direction.\n"
ELSEIF Command="DOES THE STAGE RETURN TO START AT END OF TRAVEL?"THEN
IF auto_return THEN
WRITECOM 2,"The stage returns to start at end of travel.\n"
ELSE
WRITECOM 2,"The stage does not return to start at end of travel.\n"
END IF
ELSEIF Command="RETURN TO START AT END OF TRAVEL"THEN
auto_return=1
auto_reverse=0
WRITECOM 2,"The stage returns to start at end of travel.\n"
ELSEIF Command="DO NOT RETURN TO START AT END OF TRAVEL"THEN
auto_return=0
WRITECOM 2,"The stage does not return to start at end of travel.\n"
ELSEIF Command="TRAVEL LIMITS?"THEN
FORMAT reply,"Travel is limited from %g to %g mm.\n",
DBLV:start_pos*res,DBLV:end_pos*res
WRITECOM 2,reply
ELSEIF FindStrInStr(LIMIT_TRAVEL_FROM_,Command)=0 THEN
old_start_pos=start_pos
old_end_pos=end_pos
offset=LEN(LIMIT_TRAVEL_FROM_)
CALL ExtractStrFromStr(Command,parameter,offset,LEN(Command)-offset)
start_pos=CDBL(parameter)/res
offset=FindStrInStr(TO_,Command)+LEN(TO_)
CALL ExtractStrFromStr(Command,parameter,offset,LEN(Command)-offset)
end_pos=CDBL(parameter)/res
FORMAT reply,"Travel is limited from %g to %g mm.\n",
DBLV:start_pos*res,DBLV:end_pos*res
WRITECOM 2,reply
ELSEIF Command="START POSITION?"THEN
FORMAT reply,"Start position is %g mm.\n",DBLV:start_pos*res
WRITECOM 2,reply
ELSEIF FindStrInStr(START_POSITION_,Command)=0 THEN
old_value=start_pos
offset=LEN(START_POSITION_)
CALL ExtractStrFromStr(Command,parameter,offset,LEN(Command)-offset)
start_pos=CDBL(parameter)/res
FORMAT reply,"Start position is %g mm.\n",DBLV:start_pos*res
WRITECOM 2,reply
ELSEIF Command="END POSITION?"THEN
FORMAT reply,"End position is %g mm.\n",DBLV:end_pos*res
WRITECOM 2,reply
ELSEIF FindStrInStr(END_POSITION_,Command)=0 THEN
old_value=end_pos
offset=LEN(END_POSITION_)
CALL ExtractStrFromStr(Command,parameter,offset,LEN(Command)-offset)
end_pos=CDBL(parameter)/res
FORMAT reply,"End position is %g mm.\n",DBLV:end_pos*res
WRITECOM 2,reply
ELSEIF Command="IS THE DRIVE ENABLED?"THEN
bits=AXISSTATUS(0)
IF(bits>>0) BAND 1THEN
WRITECOM 2,"The drive is enabled.\n"
ELSE
WRITECOM 2,"The drive is disabled.\n"
END IF
ELSEIF Command="ENABLE DRIVE"THEN
FAULTACK 0 'Clear fault status (if present).
ENABLE 0 
WRITECOM 2,"The drive is enabled.\n"
ELSEIF Command="DISABLE DRIVE"THEN
DISABLE 0 
WRITECOM 2,"The drive is disabled.\n"
ELSEIF Command="TOP SPEED?"THEN
FORMAT reply,"Top speed is %g mm/s.\n",DBLV:speed*res
WRITECOM 2,reply
ELSEIF FindStrInStr(TOP_SPEED_,Command)=0 THEN
offset=LEN(TOP_SPEED_)
CALL ExtractStrFromStr(Command,parameter,offset,LEN(Command)-offset)
speed=CDBL(parameter)/res
FORMAT reply,"Top speed is %g mm/s.\n",DBLV:speed*res
WRITECOM 2,reply
ELSEIF Command="ACCELERATION IN TRIGGERED MODE?"THEN
FORMAT reply,"The acceleration in triggered mode is %g mm/s2.\n",
DBLV:step_acceleration*res
WRITECOM 2,reply
ELSEIF FindStrInStr(ACCELERATION_IN_TRIGGERED_MODE_,Command)=0 THEN
offset=LEN(ACCELERATION_IN_TRIGGERED_MODE_)
CALL ExtractStrFromStr(Command,parameter,offset,LEN(Command)-offset)
step_acceleration=CDBL(parameter)/res
FORMAT reply,"The acceleration in triggered mode is %g mm/s2.\n",
DBLV:step_acceleration*res
WRITECOM 2,reply
ELSEIF Command="ACCELERATION?"THEN
FORMAT reply,"The acceleration is %g mm/s2.\n",DBLV:acceleration*res
WRITECOM 2,reply
ELSEIF FindStrInStr(ACCELERATION_,Command)=0 THEN
offset=LEN(ACCELERATION_)
CALL ExtractStrFromStr(Command,parameter,offset,LEN(Command)-offset)
acceleration=CDBL(parameter)/res
FORMAT reply,"The acceleration is %g mm/s2.\n",DBLV:acceleration*res
WRITECOM 2,reply
ELSEIF Command="STOP"THEN
trigger_enabled=0
ABORT 0 
WRITECOM 2,"Stopped.\n"
ELSEIF Command="LOW LIMIT?"THEN
FORMAT reply,"The low limit is %g mm.\n",DBLV:low_limit*res
WRITECOM 2,reply
ELSEIF FindStrInStr(SET_THE_LOW_LIMIT_TO_,Command)=0 THEN
offset=LEN(SET_THE_LOW_LIMIT_TO_)
CALL ExtractStrFromStr(Command,parameter,offset,LEN(Command)-offset)
low_limit=CDBL(parameter)/res
FORMAT reply,"The low limit is %g mm.\n",DBLV:low_limit*res
WRITECOM 2,reply
ELSEIF Command="HIGH LIMIT?"THEN
FORMAT reply,"The high limit is %g mm.\n",DBLV:high_limit*res
WRITECOM 2,reply
ELSEIF FindStrInStr(SET_THE_HIGH_LIMIT_TO_,Command)=0 THEN
offset=LEN(SET_THE_HIGH_LIMIT_TO_)
CALL ExtractStrFromStr(Command,parameter,offset,LEN(Command)-offset)
high_limit=CDBL(parameter)/res
FORMAT reply,"The high limit is %g mm.\n",DBLV:high_limit*res
WRITECOM 2,reply
ELSEIF Command="TRIGGER COUNT?"THEN
FORMAT reply,"The trigger count is %d.\n",INTV:trigger_count
WRITECOM 2,reply
ELSEIF FindStrInStr(TRIGGER_COUNT_,Command)=0 THEN
offset=LEN(TRIGGER_COUNT_)
CALL ExtractStrFromStr(Command,parameter,offset,LEN(Command)-offset)
trigger_count=CINT(parameter)
FORMAT reply,"The trigger count is %d.\n",INTV:trigger_count
WRITECOM 2,reply
ELSEIF Command="STEP COUNT?"THEN
FORMAT reply,"The step count is %d.\n",INTV:step_count
WRITECOM 2,reply
ELSEIF FindStrInStr(STEP_COUNT_,Command)=0 THEN
offset=LEN(STEP_COUNT_)
CALL ExtractStrFromStr(Command,parameter,offset,LEN(Command)-offset)
step_count=CINT(parameter)
FORMAT reply,"The step count is %d.\n",INTV:step_count
WRITECOM 2,reply
ELSEIF Command="SAVE PARAMETERS"THEN
CALL Save_Parameters()
WRITECOM 2,"Saving Parameters.\n"
ELSEIF Command="SOFTWARE VERSION?"THEN
WRITECOM 2,"Software version is "
WRITECOM 2,Version
WRITECOM 2,".\n"
ELSEIF Command="?"THEN'Return a list of commands.
'The maximum number of bytes that in a string seems to be 256.
'Thus, several WRITECOM calls are needed to send back the complete list.
 WRITECOM 2,"Available commands:\n"
WRITECOM 2,"Is the stage moving?\n"
WRITECOM 2,"Current position?\n"
WRITECOM 2,"Go to <value>.\n"
WRITECOM 2,"Command position?\n"
WRITECOM 2,"Is trigger enabled?\n"
WRITECOM 2,"Enable trigger.\n"
WRITECOM 2,"Disable trigger.\n"
WRITECOM 2,"Is timer enabled?\n"
WRITECOM 2,"Enable timer.\n"
WRITECOM 2,"Disable timer.\n"
WRITECOM 2,"Timer period?\n"
WRITECOM 2,"Timer period <value> s.\n"
WRITECOM 2,"Step size?\n"
WRITECOM 2,"Step size <value> mm.\n"
WRITECOM 2,"Calibrate the stage.\n"
WRITECOM 2,"Is the stage calibrated?\n"
WRITECOM 2,"Is the stage at high limit?\n"
WRITECOM 2,"Is the stage at low limit?\n"
WRITECOM 2,"Does the stage change direction at travel limits?\n"
WRITECOM 2,"Change direction at travel limits.\n"
WRITECOM 2,"Do not change direction.\n"
WRITECOM 2,"Travel limits?\n"
WRITECOM 2,"Limit travel from <value> to <value>.\n"
WRITECOM 2,"Start position?\n"
WRITECOM 2,"Start position <value> mm.\n"
WRITECOM 2,"End position?\n"
WRITECOM 2,"End position <value> mm.\n"
WRITECOM 2,"Is the drive enabled?\n"
WRITECOM 2,"Disable drive.\n"
WRITECOM 2,"Enable drive.\n"
WRITECOM 2,"Top speed?\n"
WRITECOM 2,"Top speed <value>.\n"
WRITECOM 2,"Acceleration in triggered mode?\n"
WRITECOM 2,"Acceleration in triggered mode <value>.\n"
WRITECOM 2,"Acceleration ?\n"
WRITECOM 2,"Acceleration <value>.\n"
WRITECOM 2,"Stop.\n"
WRITECOM 2,"Low limit?\n"
WRITECOM 2,"High limit?\n"
WRITECOM 2,"Trigger Count?\n"
WRITECOM 2,"Trigger Count <count>.\n"
WRITECOM 2,"Step Count?\n"
WRITECOM 2,"Step Count <count>.\n"
WRITECOM 2,"Save Parameters?\n"
WRITECOM 2,"Software version?\n"
ELSE
FORMAT reply,"Command '%s' not understood.\n",STRV:Command
WRITECOM 2,reply
END IF

Command=""'Reset command buffer after command is processed.
 END IF
END IF
END IF
END FUNCTION
