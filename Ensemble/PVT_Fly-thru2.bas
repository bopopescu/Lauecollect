' PVT commands are queued in a FIFO buffer of length 16. Use HALT to 
' hold off execution of the PVT commands until a START command is issued.
' To ensure the FIFO buffer is not overwritten, the 14th PVT command 
' automatically triggers a START. Hence, to properly synchronize
' the motion, the START command must be issued before the 14th PVT 
' command is queued in the FIFO buffer. 

'Arrays such are indexed from 0 to N; i.e., A(1) has two elements


DECLARATIONS
GLOBAL PrintString AS STRING(120)
GLOBAL Zpos AS DOUBLE
GLOBAL Z_mid AS DOUBLE
GLOBAL Zvmax_RS AS DOUBLE
GLOBAL DT_start AS DOUBLE
GLOBAL scale_factor AS DOUBLE
GLOBAL Ti AS DOUBLE
GLOBAL N_mode AS INTEGER
GLOBAL N_delay AS INTEGER
GLOBAL N_count AS INTEGER
GLOBAL msShut_Enable AS INTEGER
GLOBAL PumpA_Enable AS INTEGER
GLOBAL PP(500,9)AS DOUBLE'Peristaltic Pump Look-up Table
'GLOBAL SS_array(9) AS INTEGER 'Steps/Stroke for PumpA

END DECLARATIONS

'IGLOBAL(0): setting to -1 initiates orderly exit of this program
'IGLOBAL(1): setting to 1 Triggers Digitial Oscilloscope
'IGLOBAL(2): Environment Index (0: NIH; 1: APS; 2: LCLS --- Specify E_INDEX BEFORE LAUNCHING THIS PROGRAM!)
'IGLOBAL(3): Peristaltic Pump Index (0: linear; 1-9: nonlinear options)

 PROGRAM 
DIM E_index AS INTEGER
DIM DT_array(2)AS DOUBLE'Period of Base frequency (in seconds)
 DIM scale_factor_array(2)AS DOUBLE'
DIM Open_array()AS DOUBLE={56,9.6999999999999993,56}'Shutter open (0:NIH, 1:APS, 2:LCLS)
 DIM msShut_step_array()AS DOUBLE={7,10,7}'Step size to move from open to close (in degrees)
 DIM Xo AS DOUBLE,Yo AS DOUBLE,Zo AS DOUBLE'Starting position


'Useful Commands:
'	IGLOBAL(0) = -1					'Exit program
'	moveabs msShut_ext 9.7			'move msShut_ext to APS open position
'	moveinc PumpA -700  PumpAF 50	'retract solution from capillary 
'	moveinc PumpA 2100  PumpAF 50	'flush capillary 
'	DGLOBAL(1) = 1					'trigger digital oscilloscope

'Set operating parameters
 E_index=0'Environment index (0: NIH; 1: APS; 2: LCLS ---Specify appropriate E_INDEX BEFORE LAUNCHING THIS PROGRAM!)
 DZ=-0.5'The full stroke is defined to be (DZ*N_steps) 
 N_steps=46'5 for LZ offset; 39 for 40 x-ray shots; 2 for acceleration/deceleration
Z_stop=-10.5'Stroke stops at this position 
 Z_start=Z_stop-DZ*N_steps'Stroke starts at this position	
 N_return=72'Number of time steps for return stroke

'Initialize DT array 
 DT_array(0)=(1.0055257142857144)*0.024304558/24'0: NIH base period  (0.0010183 based on internal oscillator for Pico23)							
DT_array(1)=0.0010126899166666666'1: APS base period  (0.0010127 275th subharmonic of P0)
DT_array(2)=0.0010416666666666667'2: LCLS base period (0.0010417 inverse of 8*120 = 960 Hz)

'Initialize scale_factor_array (rescales DT to approximately match the source frequency)
 scale_factor_array(0)=1.00000427'1.0000018 'Pico23 
scale_factor_array(1)=0.99999035999999997'APS 2017.02.26; 0.99999084 APS 2016.11.08; 0.99999525 'APS 03/07/2016
 scale_factor_array(2)=1'LCLS 

'Select Environment-dependent parameters
 DT_start=DT_array(E_index)
msShut_open=open_array(E_index)
msShut_step=msShut_step_array(E_index)
msShut_atten=56'NIH/LCLS attenuated position (in degrees)
 msShut_close1=msShut_open-msShut_step
msShut_close2=msShut_open+msShut_step
scale_factor=scale_factor_array(E_index)'If time correction is positive (us), need to decrease the scale factor.

'Calculate operating parameters
 Z_mid=0.5*(Z_start+Z_stop)'mid-point of the stroke
 DT=scale_factor*DT_start
Zvmax_RS=1.5*(Z_start-Z_stop)/(N_return*DT)'peak velocity during return stroke.

'Initial conditions
 Ti=0.001
LZi=0
Npp=0
Zi=Z_start
msShut_pos=msShut_close1
CALL PP_Array()

Plane 1
RECONCILE 0,1,2,4,5,6

'Move to starting positions
 ABS'Positions specified in absolute coordinates
WAIT MODE MOVEDONE 

MOVEABS 2:Zi:10 
MOVEABS 5:LZi:10 
MOVEABS 6:msShut_close1 

PumpA_pos=PCMD(4)
MOVEABS 4:50*CEIL(PumpA_pos/50):20 'Move PumpA to the next largest multiple of 50 before terminating program.	
HOME 4
PumpA_pos=PCMD(4)



'Set up for PVT commands
PVT_INIT  @1 
 VELOCITY ON
HALT

DGLOBAL(0)=0
'GOTO EndOfProgram
 N_delay=0
N_count=0
T_last=Ti
Last_mode=-1
DGLOBAL(1)=0

SCOPEBUFFER 2500
SCOPETRIGPERIOD 1' -4 (-2) corresponds to 4 (2) kHz

PVT 2: Zi, 0,4: PumpA_pos, 0,5: LZi, 0,6: msShut_pos, 0 @Ti 

CALL Synch()
WHILE IGLOBAL(0)>-1'enter IGLOBAL(0) = -1 to exit loop
 PP_index=IGLOBAL(3)'0 is linear; 1 is nonlinear
CALL Synch()'Read msShut_Enable, PumpA_Enable, N_mode, and N_delay	
 STARTSYNC 4'Start motion 4 ms after CALL Synch() finishes
 IF N_mode=10 THEN
'Acquire scope trace on second stroke, or when DGLOBAL(1)=1
 IF(N_count=1)OR(DGLOBAL(1)=1)THEN
SCOPEBUFFER 1200
SCOPETRIGPERIOD-4' -4 (-2) corresponds to 4 (2) kHz
SCOPETRIG
DGLOBAL(1)=0
END IF
M_scale=4
ZV=DZ/( M_scale*DT)
Ti=Ti+8*DT
Zi=Zi+DZ
PVT 2: Zi, ZV,6: msShut_pos, 0 @Ti 
Ti=Ti+3*M_scale*DT
Zi=Zi+3*DZ
PVT 2: Zi, ZV,6: msShut_pos, 0 @Ti 
Ti=Ti+2*M_scale*DT
Zi=Zi+2*DZ
IF msShut_Enable=1 THEN
msShut_pos=msShut_open
END IF
PVT 2: Zi, ZV,6: msShut_pos, 0 @Ti 
Ti=Ti+39*M_scale*DT
Zi=Zi+39*DZ
PVT 2: Zi, ZV,6: msShut_pos, 0 @Ti 
Ti=Ti+8*DT
Zi=Zi+DZ
msShut_pos=msShut_close1
IF PumpA_Enable=1 THEN
PVT 2: Zi, 0,4: PumpA_pos, 0,5: LZi, 0,6: msShut_pos, 0 @Ti 
'Return Stroke
 Ti=Ti+N_return*DT+T_corr
Zi=Z_start
LZi=-1*ZV*10^(N_delay/8-5)'LZ position for L_delay
 Npp=Npp+PumpA_Enable
PumpA_pos=50*FLOOR(Npp/100)+PP(Npp-100*FLOOR(Npp/100),PP_index)
PVT 2: Zi, 0,4: PumpA_pos, 0,5: LZi, 0,6: msShut_pos, 0 @Ti 
ELSE
PVT 2: Zi, 0,5: LZi, 0,6: msShut_pos, 0 @Ti 
'Return Stroke
 Ti=Ti+N_return*DT+T_corr
Zi=Z_start
LZi=-1*ZV*10^(N_delay/8-5)'LZ position for L_delay
PVT 2: Zi, 0,5: LZi, 0,6: msShut_pos, 0 @Ti 
 END IF
IF N_count=0 THEN
SYNC
START
END IF
ELSEIF N_mode=11 THEN
'Acquire scope trace on second stroke, or when DGLOBAL(1)=1
 IF(N_count=1)OR(DGLOBAL(1)=1)THEN
SCOPEBUFFER 2500
SCOPETRIGPERIOD 1' -4 (-2) corresponds to 4 (2) kHz
SCOPETRIG
DGLOBAL(1)=0
END IF
M_scale=48
ZV=DZ/( M_scale*DT)
Ti=Ti+12*DT
Zi=Zi+DZ
PVT 2: Zi, ZV,6: msShut_pos, 0 @Ti 
Ti=Ti+4*M_scale*DT
Zi=Zi+4*DZ
PVT 2: Zi, ZV,6: msShut_pos, 0 @Ti 
IF N_count=0 THEN
SYNC
START
END IF
FOR i=1 TO 20
Ti=Ti+( M_scale-4)*DT
Zi=Zi+(1-4/M_scale)*DZ
PVT 2: Zi, ZV,6: msShut_pos, 0 @Ti 
Ti=Ti+8*DT
Zi=Zi+(8/M_scale)*DZ
IF msShut_Enable=1 THEN
msShut_pos=msShut_close2
END IF
PVT 2: Zi, ZV,6: msShut_pos, 0 @Ti 
Ti=Ti+( M_scale-8)*DT
Zi=Zi+(1-8/M_scale)*DZ
PVT 2: Zi, ZV,6: msShut_pos, 0 @Ti 
Ti=Ti+8*DT
Zi=Zi+(8/M_scale)*DZ
msShut_pos=msShut_close1
PVT 2: Zi, ZV,6: msShut_pos, 0 @Ti 
Ti=Ti-4*DT
Zi=Zi-(4/M_scale)*DZ
NEXT i
Ti=Ti+12*DT
Zi=Zi+DZ
IF PumpA_Enable=1 THEN
PVT 2: Zi, 0,4: PumpA_pos, 0,5: LZi, 0,6: msShut_pos, 0 @Ti 
'Return Stroke
 Ti=Ti+N_return*DT+T_corr
Zi=Z_start
LZi=-1*ZV*10^(N_delay/8-5)'LZ position for L_delay
 Npp=Npp+PumpA_Enable
PumpA_pos=50*FLOOR(Npp/100)+PP(Npp-100*FLOOR(Npp/100),PP_index)
PVT 2: Zi, 0,4: PumpA_pos, 0,5: LZi, 0,6: msShut_pos, 0 @Ti 
ELSE
PVT 2: Zi, 0,5: LZi, 0,6: msShut_pos, 0 @Ti 
'Return Stroke
 Ti=Ti+N_return*DT+T_corr
Zi=Z_start
LZi=-1*ZV*10^(N_delay/8-5)'LZ position for L_delay
PVT 2: Zi, 0,5: LZi, 0,6: msShut_pos, 0 @Ti 
 END IF
END IF

CALL Phase()
N_count=N_count+1
Last_mode=N_mode
WEND
'To ensure FIFO buffer is flushed, execute START command;
'	without START, PLANESTATUS(1) in loop below can return 32
START
VELOCITY OFF
LINEAR 4:50*CEIL(Npp/100),5:0 @20 'Move PumpA to the next largest multiple of 50 before terminating program.		
WHILE PLANESTATUS(1)>0'wait for PVT motion to be complete.
 P_status=PLANESTATUS(1)
DWELL 0.0050000000000000001
WEND
PLANE 0
RECONCILE 0,1,2,4,5,6
EndOfProgram:
END PROGRAM 

FUNCTION PP_Array()
'Estimate Peristaltic Pump position using 5th order polynomial
 DIM i AS INTEGER
'SS_array(0) = 50
'SS_array(1) = 100
 FOR i=0 TO 99' Assign positions for 100 steps
PP(i,0)=i
NEXT i
FOR i=0 TO 99' Assign positions for 100 steps
v=i*24.699999999999999/99
PP(i,1)=1.843*v-0.0066010000000000001*v^2+0.0038279999999999998*v^3-0.00043209999999999999*v^4+1.1590000000000001e-005*v^5
NEXT i
END FUNCTION

FUNCTION Synch()
DIM N_temp AS INTEGER
'Decode mode parameters from trigger pulse train
 STARTSYNC-1'corresponds to 0.5 ms clock ticks per SYNC 
 WHILE DIN:0::( 1,0)=0'wait for next low-to-high transition.
 SYNC
WEND
'Record Zpos immediately after first rising edge
 Zpos=PCMD(2)
SYNC
SYNC
SYNC
SYNC
SYNC
SYNC
SYNC
'Record msShut_Enable 3.5 ms after first rising edge
 msShut_Enable=DIN:0::( 1,0)
SYNC
SYNC
SYNC
SYNC
'Record PumpA_Enable 2 ms later
 PumpA_Enable=DIN:0::( 1,0)
'Read 4 bits that define mode (every 2 ms)
 N_temp=0
FOR i=0 TO 3
SYNC
SYNC
SYNC
SYNC
N_temp=N_temp+DIN:0::( 1,0)*2^i
NEXT i
N_mode=N_temp
'Read 6 bits that define delay (every 2 ms)
 N_temp=0
FOR i=0 TO 5
SYNC
SYNC
SYNC
SYNC
N_temp=N_temp+DIN:0::( 1,0)*2^i
NEXT i
N_delay=N_temp
END FUNCTION

FUNCTION Phase()
' Monitor and correct phase of motion(PLL)
T_corr=0
IF N_count=0 THEN
T_ref=0'Last time used to compute scale_factor
 N_corr=50'Number of strokes between corrections
 Z_error_max=-10
Z_error_min=10
T_corr_sum=0
pos_error_sum=0'If exceeds limits, used to correct scale factor
 PRINT"N_count, Mode, Z_error_range [um], pos_error [um],"
PRINT"Ti [s], scale factor, T_corr [us], T_corr_sum [us]"
PRINT"\r"
ELSEIF N_count>1 THEN
'Maintain upper, lower limits of error; use to calculate pos_error.

Z_error=Zpos-Z_mid
IF Z_error<Z_error_min THEN
Z_error_min=Z_error
END IF
IF Z_error>Z_error_max THEN
Z_error_max=Z_error
END IF
pos_error=0.5*(Z_error_max+Z_error_min)
Z_error_range=Z_error_max-Z_error_min
'T_corr = pos_error/Zvmax_RS
'IF ABS(T_corr) > 0.002 THEN
'	PRINT "Large Position Error \r"
'	FORMAT PrintString, "%.0f\r",DBLV:1000*pos_error
'	T_corr = 0
'	pos_error = 0
'END IF		

IF N_count=N_corr*FLOOR(N_count/N_corr)THEN'make correction								
 T_corr=pos_error/Zvmax_RS
T_corr_sum=T_corr_sum+T_corr
Z_error_max=Z_error_max-pos_error-DGLOBAL(3)
Z_error_min=Z_error_min-pos_error+DGLOBAL(3)
DGLOBAL(3)=0.0040000000000000001
IF N_count>(4*N_corr)THEN
pos_error_sum=pos_error_sum+pos_error
IF(abs(pos_error_sum)>0.050000000000000003)AND((Ti-T_ref)>300)THEN
scale_factor=scale_factor*(1+pos_error_sum/Zvmax_RS/(Ti-T_ref))
DT=scale_factor*DT_start
pos_error_sum=0
T_ref=Ti
END IF
END IF
FORMAT PrintString,"%d,%d,%.0f,%.0f,%.1f,%.8f,%.0f,%.0f\r",
INTV:N_count,INTV:N_mode,DBLV:1000*Z_error_range,DBLV:1000*pos_error,DBLV:Ti,DBLV:scale_factor,DBLV:1000000*T_corr,DBLV:1000000*T_corr_sum
PRINT PrintString
END IF
END IF

END FUNCTION
