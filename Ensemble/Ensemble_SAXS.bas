' version 1.6.0
DECLARATIONS

TYPE PVT_parameters'32-bit single-precision float for position/velocity; integer for [1/0]
Zp AS SINGLE'Z axis position
 Zv AS SINGLE'Z axis velocity; [-1 to 1]
 Sp AS SINGLE'Shutter position; [-1 to 1]; 0 is open
 Sv AS SINGLE'Shutter velocity [-1 to 1]
 L AS INTEGER'Laser
 X AS INTEGER'X-ray
 D AS INTEGER'Digital Output
 END TYPE

GLOBAL PrintString AS STRING(120)
'GLOBAL N_steps() AS INTEGER = {249,2405,375,189,174,44,249,372,501,618,45} 'old with error in Exotic-32
 GLOBAL N_steps()AS INTEGER={249,2405,516,516,516,44,249,516,501,84}

GLOBAL PVD(10,618)AS PVT_parameters
'GLOBAL PP() AS SINGLE = {0,1.4,2.5,3.6,4.5,5.4,6.3,7.2,8,8.8,9.7,10.5,11.3,12.1,13,13.8,14.6,15.4,16.2,17.1,17.9,18.7,19.5,20.3,21.2,22,22.8,23.6,24.4,25.1,25.9,26.7,27.5,28.3,29,29.8,30.6,31.3,32.1,32.9,33.7,34.5,35.3,36.2,37.1,38,39,40,41.2,42.5}
'PP is peristaltic pump vector that linearizes volume dispensed over a 50 step stroke
 GLOBAL PP(100)AS SINGLE
END DECLARATIONS

 PROGRAM 

'Useful Commands 
'	DGLOBAL(0) = -1
'	moveabs msShut_ext 9.7
'	moveinc PumpA -700  PumpAF 50
'	moveinc PumpA 2100  PumpAF 50
'	DGLOBAL(3) = -0.1

DIM i AS INTEGER,j AS INTEGER,Last_mode AS INTEGER
DIM Di AS INTEGER
DIM Itemp AS INTEGER
DIM msShut_Enable AS INTEGER
DIM PumpA_Enable AS INTEGER

DIM O_mode AS INTEGER,M AS INTEGER,E_index AS INTEGER
DIM DT_array(2)AS DOUBLE'Period of Base frequency (in seconds)
 DIM scale_factor_array(2)AS DOUBLE'
DIM Period_array()AS INTEGER={12,12,8}'period between x-ray pulses in units of DT (0:NIH, 1:APS, 2:LCLS)
 DIM Open_array()AS DOUBLE={56,9.6999999999999993,56}'Shutter open (0:NIH, 1:APS, 2:LCLS)
 DIM Close_array()AS DOUBLE={63,19.699999999999999,63}'Shutter close (0:NIH, 1:APS, 2:LCLS)
 DIM msShut_step_array()AS DOUBLE={7,10,7}'Step size to move from open to close (in degrees)
 DIM Xo AS DOUBLE,Yo AS DOUBLE,Zo AS DOUBLE'Starting position

' Specify Environment Index and whether the digital oscilloscope should be set to operate
E_index=1'Environment index (0: NIH; 1: APS; 2: LCLS ---Specify appropriate E_INDEX BEFORE LAUNCHING THIS PROGRAM!)
 D_Scope=0'[1/0] Enables/Disables Digital Oscilloscope
Trig_delay=5.5'trigger propagation delay in units of DT (trig to DIO delay is 4.5 +/- 0.3 ms on oscilloscope)

'Initialize DT array 
 DT_array(0)=(1.0055257142857144)*0.024304558/24'0: NIH base period  (0.0010183 based on internal oscillator for Pico23)							
DT_array(1)=0.0010126899166666666'1: APS base period  (0.0010127 275th subharmonic of P0)
DT_array(2)=0.0010416666666666667'2: LCLS base period (0.0010417 inverse of 8*120 = 960 Hz)

'Initialize scale_factor_array (rescales DT to approximately match the source frequency)
 scale_factor_array(0)=1.000005'1.0000018 'Pico23 
scale_factor_array(1)=0.99999035999999997'APS 2017.02.26; 0.99999084 APS 2016.11.08; 0.99999525 'APS 03/07/2016
 scale_factor_array(2)=1'LCLS 

'Select Environment-dependent parameters
 DT_start=DT_array(E_index)
msShut_open=open_array(E_index)
msShut_close=close_array(E_index)
msShut_step=msShut_step_array(E_index)
msShut_atten=56'NIH/LCLS attenuated position (in degrees)
 msShut_close1=msShut_open-msShut_step
msShut_close2=msShut_open+msShut_step
M_offset=Period_array(E_index)/2-Trig_delay
scale_factor=scale_factor_array(E_index)'If time correction is positive (us), need to decrease the scale factor.

DGLOBAL(0)=0' Use to keep While Loop running (-1 finishes execution)
DGLOBAL(1)=0.94999999999999996' timing correction in units of DT 04.03.2016
DGLOBAL(2)=20'# x-ray pulses transmitted in Idle mode (even number)
DGLOBAL(3)=0.0040000000000000001

Verbose=0'If Verbose is True, then print after every stroke; else only after timing correction

T_ref=0'Time used to compute new scale_factor
 N_corr=25'Number of strokes between corrections
 Z_error_max=-10
Z_error_min=10
Sum_corrections=0
PRINT"k, Mode, Z_error_max [um], Z_error_min [um], pos_error [um],"
PRINT"T_0 [s], scale factor, T_correction [us], Sum_corrections [us]"
PRINT"\r"

' Initialize Zp and Sp
FOR j=0 TO 10
FOR i=0 TO 618
PVD(j,i).Zp=-1' -1 is a flag to suppress PVT commands
PVD(j,i).Sp=-1' -1 is the normal closed state (close1)
NEXT i
NEXT j

'Call functions to specify parameters required for the respective modes
 CALL Exotic()
CALL Stepping()
CALL Flythru()
CALL Flythru_LCLS()
CALL PP_Array()

'GOTO EndOfProgram

T_offset=0.69999999999999996'2.2 'time offset in units of DT; centers msShut_ext opening on x-ray pulse
Z_offset=0.434'Z offset required to center trigger pulse on middle slot of sample cell

DT=scale_factor*DT_start

'Slotted Sample Cell parameters
 Nslots=41
DZ=0.59999999999999998'slot separation
'Z_1 = -11.480' at APS; slot 1 position w/ cooling water set to 15 Celsius.
'Z_1 = -11.51 ' Sample cell 3 at NIH
'Z_1 = -11.219' Sample cell 5 at APS; 
'Z_1 = -11.2445 ' Sample cell 2 at NIH
'Z_1 = -11.41 ' Sample cell ? at APS
'Z_1 = -12.23 ' Sample cell 5 at APS
 Z_1=-11.673999999999999' 2017.02.24
'Z_1 = -11.374 
'Z_1 = -8.1
 Z_start=Z_1-DZ
Z_end=Z_start+( Nslots+1)*DZ' end-point of the stroke
Z_mid=Z_start+0.5*( Nslots+1)*DZ'mid-point of the stroke
 Z_v=DZ/(4*DT)'velocity of sample cell in fly-thru mode (~150 mm/s)
 Zvmax_RS=1.5*(Nslots+1)*DZ/(60*DT)'Z velocity at midpoint of Return Stroke (mm/s)

'Axis Z parameters
'SETGAIN <Axis>, <GainKp>, <GainKi>, <GainKpos>, <GainAff>
'SETGAIN sets all 4 parameters synchronously
'SETGAIN Z, 1780000, 10000, 56.2, 56200 'original settings (20 kHz)
'SETGAIN Z, 129500, 6526, 206.5, 64460 'original settings (4 kHz)
'SETGAIN Z, 122900, 1254, 41.8, 49020 'original settings (10 kHz)
'SETGAIN Z, 96512, 2627, 111, 57783 'AutoTune(1)
'SETPARM Z, GainVff, 0 'original setting
'SETGAIN Z, 1780000, 7500, 133, 5620 'New settings
'SETPARM Z, GainVff, 3162

'Millisecond shutter parameters; determined at BioCARS in Feb 2015
'SETGAIN msShut_ext, 180900, 2621, 59, 260700
'SETPARM msShut_ext, GainVff, 5932

'Reconcile, then find current position of Z, PumpA, and msShut_ext. 
 Plane 1
RECONCILE 2,4,6
Z_pos=PCMD(2)
PumpA_pos=PCMD(4)
msShut_current=PCMD(6)

resynch:'resynch if necessary

'Move PumpA to the next largest multiple of 50 before resetting to zero.
'  Npp is the number of times the PumpA was moved since starting.
WAIT MODE MOVEDONE 
MOVEABS 4:50*CEIL(PumpA_pos/50):20 
'WAIT MOVEDONE PumpA
HOME 4
 PumpA_pos=0
Npp=0



DOUT:0::1, 0'Ensure all bits of digital output are low when starting

'Set up for PVT calls
 ABS'Positions specified in absolute coordinates
PVT_INIT  @1 
 VELOCITY ON
HALT



'Wait for start of pulse pattern to synchronize start of motion
 WHILE DIN:0::( 1,0)=1'wait till input is low 
 DWELL 0.00025000000000000001
WEND
WHILE DIN:0::( 1,0)=0'wait for next low-to-high transition.
 DWELL 0.00025000000000000001
WEND
DWELL 0.029999999999999999'wait till after burst is over (30 ms is more than enough.
 STARTSYNC-1'query every 0.5 ms
 WHILE DIN:0::( 1,0)=0'wait for next low-to-high transition.
 SYNC
WEND

Zpos=PCMD(2)
'Decode mode from trigger pulse train
'Record msShut_Enable 3.5 ms after trigger (middle of pulse)
 SYNC
SYNC
SYNC
SYNC
SYNC
SYNC
SYNC
msShut_Enable=DIN:0::( 1,0)
'Record PumpA_Enable 2 ms later
 SYNC
SYNC
SYNC
SYNC
PumpA_Enable=DIN:0::( 1,0)
'Read bits that define mode every 2 ms
 j=0
FOR i=0 TO 3
SYNC
SYNC
SYNC
SYNC
j=j+DIN:0::( 1,0)*2^i
NEXT i

Last_mode=0
'j=5	'Force fly-thru

'Synchronize start (timing is mode dependent).

T_0=((N_steps(j)+15)*4+Trig_delay+1.8)*DT' 07.03.2016 + 1.8 is offset required to properly synchronize the start
Scope_Trigger_Delay=T_0-0.10000000000000001' Start recording 100 ms before the start of the scan.
Npts=8*N_steps(j)+400
SCOPETRIGPERIOD-2' 0.5 ms per point
SCOPEBUFFER(200*CEIL(Npts/200))'Round up to nearest 100 ms

'Move motors into position to start.
 FORMAT PrintString,"%.3f,%.3f,%.3f\r",DBLV:Z_pos,DBLV:Z_end,DBLV:Z_start
PRINT PrintString
PVT 2: Z_pos, 0,4: PumpA_pos, 0,6: msShut_current, 0 @0.001 |DOUT 0:1, 0,1 
PVT 2: Z_end, 0,4: PumpA_pos, 0,6: msShut_close1, 0 @( T_0-60*DT) |DOUT 0:1, 0,1 
PVT 2: Z_start, 0,4: PumpA_pos, 0,6: msShut_close1, 0 @T_0 |DOUT 0:1, 0,1 
START

DWELL Scope_Trigger_Delay'Delay to synchronize scope near the start of the scan.
 SCOPETRIG


k=0
T_correction_old=0

WHILE DGLOBAL(0)>-1'enter DGLOBAL(0) = -1 to exit loop

STARTSYNC-1
WHILE DIN:0::( 1,0)=1'wait till input is low 
 SYNC
WEND
'DWELL 0.025	'wait 25 ms to make sure the following rising edge is not from the current pulse pattern 
 WHILE DIN:0::( 1,0)=0'wait for next low-to-high transition.
 SYNC
WEND

Zpos=PCMD(2)
'Decode mode from trigger pulse train
'Record msShut_Enable 3.5 ms after trigger (middle of pulse)
 SYNC
SYNC
SYNC
SYNC
SYNC
SYNC
SYNC
msShut_Enable=DIN:0::( 1,0)
'Record PumpA_Enable 2 ms later
 SYNC
SYNC
SYNC
SYNC
PumpA_Enable=DIN:0::( 1,0)
'Read bits that define mode every 2 ms
 j=0
FOR i=0 TO 3
SYNC
SYNC
SYNC
SYNC
j=j+DIN:0::( 1,0)*2^i
NEXT i

IF(j>0)AND(Last_mode=0)THEN
'WAIT MODE MOVEDONE
'WAIT MOVEDONE X Y Z PumpA msShut_ext 
'RECONCILE PumpA 
 END IF
'j=5	'Force fly-thru

Svmax=2*msShut_step/(8*DT)'Max S velocity is 2 time the average velocity
 Zvmax=DZ/(4*DT)'Max Z velocity for Exotic and Fly-thru Modes
 IF j>5 AND j<9 THEN
Zvmax=2*DZ/(12*DT)'Max Z velocity for Stepping Modes
 END IF

'GOTO bypass

IF j>1 THEN' Not Idle nor Single-slot modes
PumpA_step=DGLOBAL(1)' Number of motor steps during return stroke
FOR i=0 TO N_steps(j)
flag=PVD(j,i).Zp
IF flag>-1THEN
Ti=T_0+i*4*DT
Zi=Z_start+DZ*PVD(j,i).Zp
Zv=Zvmax*PVD(j,i).Zv
IF msShut_Enable THEN
Sp=msShut_open+msShut_step*PVD(j,i).Sp
Sv=Svmax*PVD(j,i).Sv
Di=-1*ABS(PVD(j,i).Sp)+1'xray shutter open
 IF PVD(j,i).L>0 THEN' Laser on
Di=Di+2
END IF
ELSE
Sp=msShut_close1
Sv=0
Di=0
END IF
Itemp=PVD(j,i).Zp
IF Itemp=1 THEN' Trigger camera on Slot 1
Di=Di+4
END IF
PVT 2: Zi, Zv,4: PumpA_pos, 0,6: Sp, Sv @Ti |DOUT 0:1, Di,15 
END IF
NEXT i
T_0=T_0+( N_steps(j)+15)*4*DT
Npp=Npp+PumpA_Enable
PumpA_pos=50*FLOOR(Npp/100)+PP(Npp-100*FLOOR(Npp/100))
'PumpA_pos = PumpA_pos + PumpA_step*PumpA_Enable
PVT 2: Z_start, 0,4: PumpA_pos, 0,6: msShut_close1, 0 @T_0 |DOUT 0:1, 0,15 

ELSEIF j=0 THEN
' Idle mode (open/close ms_Shut_ext Npulses times)	
IF msShut_Enable THEN
NP=2*FLOOR(DGLOBAL(2)/2)' 0 <= NP(even) <= 40 
IF NP<0 THEN
NP=0
ELSEIF NP>40 THEN
NP=40
END IF
FOR i=1 TO NP STEP 2
Ti=T_0+24*i*DT
PVT 6: msShut_close1, 0 @( Ti-8*DT) |DOUT 0:1, 1,15 
PVT 6: msShut_open, Svmax @Ti |DOUT 0:1, 3,15 
PVT 6: msShut_close2, 0 @( Ti+8*DT) |DOUT 0:1, 1,15 
PVT 6: msShut_close2, 0 @( Ti+16*DT) |DOUT 0:1, 1,15 
PVT 6:msShut_open,-1*Svmax @( Ti+24*DT) |DOUT 0:1, 3,15 
PVT 6: msShut_close1, 0 @( Ti+32*DT) |DOUT 0:1, 1,15 
Next i
END IF
PVT 2: Z_start, 0,6: msShut_close1, 0 @( Ti+40*DT) |DOUT 0:1, 0,15 
T_0=T_0+( N_steps(j)+15)*4*DT

ELSEIF j=1 THEN
' Single-Slot mode
Ti=T_0
PVT 2: Z_start, 0,4: PumpA_pos, 0,6: msShut_close2, 0 @( Ti+12*DT) |DOUT 0:1, 0,15 
FOR i=1 TO Nslots-1 STEP 2
Zi=Z_start+i*DZ
Ti=T_0+120*DT
PVT 2: Zi, 0,4: PumpA_pos, 0,6: msShut_close2, 0 @( Ti-60*DT) |DOUT 0:1, 0,15 
PVT 2: Zi, 0,4: PumpA_pos, 0,6: msShut_close2, 0 @( Ti-8*DT) |DOUT 0:1, 0,15 
PVT 2: Zi, 0,4: PumpA_pos, 0,6: msShut_open, 0 @Ti |DOUT 0:1, 5,15 
PVT 2: Zi, 0,4: PumpA_pos, 0,6: msShut_close1, 0 @( Ti+8*DT) |DOUT 0:1, 0,15 
Ti=T_0+360*DT
PVT 2: Zi+DZ, 0,4: PumpA_pos, 0,6: msShut_close1, 0 @( Ti-60*DT) |DOUT 0:1, 0,15 
PVT 2: Zi+DZ, 0,4: PumpA_pos, 0,6: msShut_close1, 0 @( Ti-8*DT) |DOUT 0:1, 0,15 
PVT 2: Zi+DZ, 0,4: PumpA_pos, 0,6: msShut_open, 0 @Ti |DOUT 0:1, 5,15 
PVT 2: Zi+DZ, 0,4: PumpA_pos, 0,6: msShut_close2, 0 @( Ti+8*DT) |DOUT 0:1, 0,15 
T_0=T_0+480*DT
NEXT i
Ti=T_0+120*DT
PVT 2: Zi+2*DZ, 0,4: PumpA_pos, 0,6: msShut_close2, 0 @( Ti-60*DT) |DOUT 0:1, 0,15 
PVT 2: Zi+2*DZ, 0,4: PumpA_pos, 0,6: msShut_close2, 0 @( Ti-8*DT) |DOUT 0:1, 0,15 
PVT 2: Zi+2*DZ, 0,4: PumpA_pos, 0,6: msShut_open, 0 @Ti |DOUT 0:1, 5,15 
PVT 2: Zi+2*DZ, 0,4: PumpA_pos, 0,6: msShut_close1, 0 @( Ti+8*DT) |DOUT 0:1, 0,15 
PVT 2: Z_end, 0,4: PumpA_pos, 0,6: msShut_close1, 0 @( Ti+120*DT) |DOUT 0:1, 0,15 

T_0=T_0+( N_steps(j)+15)*4*DT
PVT 2: Z_start, 0,6: msShut_close1, 0 @T_0 |DOUT 0:1, 0,15 
'PumpA_Pos = PLANEPOS(PumpA)
 END IF

' Monitor and correct phase of motion(PLL)
IF(j>1)AND(Last_mode>0)THEN'Measure Z error; make periodic timing corrections

Z_error=Zpos-Z_mid+DGLOBAL(1)*DT*Zvmax_RS'+ Z_offset + T_offset*DT*Zvmax_RS

IF Z_error<Z_error_min THEN
Z_error_min=Z_error
END IF
IF Z_error>Z_error_max THEN
Z_error_max=Z_error
END IF

pos_error=0.5*(Z_error_max+Z_error_min)
T_correction=pos_error/Zvmax_RS

IF abs(T_correction)>0.002 THEN
PRINT"Timing error detected, resynch required"
PRINT"\r"
'FORMAT PrintSring,"%.0f\r",DBLV:1000000*T_correction
'PRINT PrintString
 GOTO resynch
END IF

IF(k>25)AND(k/N_corr=FLOOR(k/N_corr))THEN'make correction								
 T_0=T_0-T_correction
Sum_corrections=Sum_corrections+T_correction
Z_error_max=Z_error_max-pos_error-DGLOBAL(3)
Z_error_min=Z_error_min-pos_error+DGLOBAL(3)
DGLOBAL(3)=0.0040000000000000001
IF k>(4*N_corr)THEN
sum_pos_error=sum_pos_error+pos_error
IF(abs(sum_pos_error)>0.050000000000000003)AND((T_0-T_ref)>300)THEN
scale_factor=scale_factor*(1-sum_pos_error/Zvmax_RS/(T_0-T_ref))
DT=scale_factor*DT_start
sum_pos_error=0
T_ref=T_0
END IF
END IF
FORMAT PrintString,"%d,%d,%.0f,%.0f,%.0f,%.1f,%.8f,%.0f,%.0f\r",
INTV:k,INTV:j,DBLV:1000*Z_error_max,DBLV:1000*Z_error_min,DBLV:1000*pos_error,DBLV:T_0,DBLV:scale_factor,DBLV:1000000*T_correction,DBLV:1000000*Sum_corrections

IF NOT Verbose AND T_correction<>T_correction_old THEN
PRINT PrintString
T_correction_old=T_correction
END IF
END IF
END IF

Last_mode=j

IF verbose THEN
PRINT PrintString
END IF

bypass:

k=k+1
WEND
'WAIT MODE MOVEDONE
LINEAR 4:50*CEIL(Npp/100) @20 'Move PumpA to the next largest multiple of 50 before terminating program.
LINEAR 2:0 
 PROGRAM STOP 1 
 EndOfProgram:
END PROGRAM 

FUNCTION Stepping()
'Stepping Modes: j = 6 to 8 -> [12,36,36] ms dwell times
'	N_steps = 41*(3 + dwell time steps) + 3 + [0,21,6]; N = [0,1,2] -> [249,516,501] steps
'   For N = 2, add 9 steps instead of 3 at end of stroke to make the period divisible by 48 (20.5 Hz operation)
'	
DIM i AS INTEGER,j AS INTEGER
DIM PrintString AS STRING(80)
For j=6 TO 8
IF j=6 THEN
Nperiod=6'# steps between X-ray pulses
k=3'# steps in dwell time 
ELSE
Nperiod=12'# steps between X-ray pulses
k=9'# steps in dwell time 
END IF
PVD(j,0).Zp=-1'Flag to suppress PVT command
 PVD(j,1).Zp=-1
X_count=0
FOR i=2 to N_steps(j)
IF FLOOR(i/Nperiod)=CEIL(i/Nperiod)AND(i/Nperiod)<42 THEN
'FORMAT PrintString, "%d\r",INTV:i
'PRINT PrintString
 X_count=X_count+1
PVD(j,i).X=X_count
PVD(j,i).L=X_count
PVD(j,i-k).Zp=X_count
PVD(j,i-2).Zp=X_count
PVD(j,i).Zp=X_count
PVD(j,i+2).Zp=X_count+0.7407407407407407
PVD(j,i+3).Zp=X_count+1
PVD(j,i-k).Zv=0
PVD(j,i-2).Zv=0
PVD(j,i).Zv=0
PVD(j,i+2).Zv=0.66666666666666663
IF(X_count/2-floor(X_count/2))=0 THEN' even
PVD(j,i-k).Sp=-1
PVD(j,i-2).Sp=-1
PVD(j,i).Sp=0
PVD(j,i+2).Sp=1
PVD(j,i-k).Sv=0
PVD(j,i-2).Sv=0
PVD(j,i).Sv=1
PVD(j,i+2).Sv=0
ELSE
PVD(j,i-k).Sp=1
PVD(j,i-2).Sp=1
PVD(j,i).Sp=0
PVD(j,i+2).Sp=-1
PVD(j,i-k).Sv=0
PVD(j,i-2).Sv=0
PVD(j,i).Sv=-1
PVD(j,i+2).Sv=0
END IF
END IF
NEXT i
PVD(j,N_steps(j)).Zp=42
PVD(j,N_steps(j)).Zv=0

'FOR i = 0 TO N_steps(j)
'	FORMAT PrintString, "%d,%.2f,%.2f,%.2f,%.2f\r",
'		INTV:i,DBLV:PVD(j,i).Zp,DBLV:PVD(j,i).Zv,DBLV:PVD(j,i).Sp,DBLV:PVD(j,i).Sv
'	flag = PVD(j,i).Zp
'	IF flag > -1 THEN
'		PRINT PrintString
'	END IF
'NEXT i

NEXT j

END FUNCTION

FUNCTION Exotic()
'Exotic Modes: j = 2 to 4 -> [32.4,64.8,129.6] ms delay times
'	N = [0,1,2] -> [375,189,174] steps; [Exotic-32, Exotic-64, Exotic-128]
DIM i AS INTEGER,j AS INTEGER

FOR j=2 TO 4
N=j-2
Nstroke=2^(N+2)-3
Nperiod=3*2^(N+2)-3
R0=Nstroke/Nperiod'(1/9),(5/21),(13/45): (# pulses before reversing/# steps per repeat)
L_count=0
X_count=0
PVD(j,0).Zp=-1'Flag to suppress PVT command
 PVD(j,1).Zp=-1
FOR i=2 TO N_steps(j)'Find L and X and assign values for Zp, Zv, and Sp
 R1=(i-2)/Nperiod
R2=(i+Nstroke-2)/Nperiod
DIFF1=R1-FLOOR(R1)'Laser trigger
 DIFF2=R2-FLOOR(R2)'X-ray trigger
 PVD(j,i).L=0
PVD(j,i).X=0
PVD(j,i).Zp=-1
IF(DIFF1<(R0-0.001))AND(L_count<41)THEN'constrain # of laser pulses to 41
 L_count=L_count+1
PVD(j,i).L=L_count
PVD(j,i).Zp=L_count
PVD(j,i).Zv=1
ELSEIF(DIFF2<(R0-0.001))AND(X_count<41)THEN'constrain # of X-ray pulses to 41 
 X_count=X_count+1
PVD(j,i).X=X_count
PVD(j,i).Zp=X_count
PVD(j,i).Zv=1
PVD(j,i).Sp=0'0 is open
END IF
NEXT i

'Place start/stop anchor points on either side of Nstroke slots
'	Separate anchor points by 2 time steps
FOR i=2 to N_steps(j)
Xm=PVD(j,i-1).X
Xi=PVD(j,i).X
Xp=PVD(j,i+1).X
Li=PVD(j,i).L
Lp=PVD(j,i+1).L
IF Li>0 AND Lp=0 THEN' last Laser pulse in stroke
PVD(j,i+2).Zp=PVD(j,i).Zp+1
END IF
IF Xi>0 AND Xm=0 THEN' first Xray pulse in stroke
PVD(j,i-2).Zp=PVD(j,i).Zp-1
END IF
IF Xi>0 AND Xp=0 THEN' last Xray pulse in stroke
IF N=0 THEN'Exotic-32
 PVD(j,i+2).Zp=PVD(j,i+1).Zp+0.75
PVD(j,i+2).Zv=0.5
slot=PVD(j,i).Zp
IF CEIL(slot/2)=FLOOR(slot/2)THEN' if even
'shutter transitions from close1 (-1) to close2 (1) in 4 steps 
 PVD(j,i-2).Sp=-1
PVD(j,i+1).Sp=0.84375
PVD(j,i+2).Sp=1
PVD(j,i+3).Sp=1
PVD(j,i).Sv=1
PVD(j,i+1).Sv=0.5625
ELSE' if odd
'shutter transitions from close2 (1) to close1 (-1)in 4 steps 
 PVD(j,i-2).Sp=1
PVD(j,i+1).Sp=-0.84375
PVD(j,i+2).Sp=-1
PVD(j,i+3).Sp=-1
PVD(j,i).Sv=-1
PVD(j,i+1).Sv=-0.5625
END IF
ELSE'Exotic-64 and Exotic-128
 PVD(j,i+1).Sp=-0.5'shutter transitions from open to close1 in 2 steps
 PVD(j,i+1).Sv=-1
END IF
END IF

Ll=PVD(j,i).L
IF Ll=41 THEN
IF N=1 THEN'Exotic-64
 PVD(j,i+2).Zp=42
PVD(j,i+1).Zp=41.75
PVD(j,i+1).Zv=0.5
END IF
END IF
Xi=PVD(j,i).X
IF Xi=41 THEN
PVD(j,i+2).Zp=PVD(j,i).Zp+1
IF N=0 THEN'Exotic-32
 PVD(j,i+2).Zp=42
PVD(j,i+2).Zv=0
END IF
END IF
NEXT i

IF N=0 THEN'Exotic-32
' First move Sp from -1 to 1 in 3 steps (without transmitting xray pulse)
PVD(j,2).Sp=0.48148148148148145' 2*20/27 - 1
PVD(j,3).Sp=1
PVD(j,4).Sp=1
PVD(j,2).Sv=0.88888888888888884' 4/3 * 2/3
PVD(j,3).Zp=1.75'27/32.0
PVD(j,3).Zv=0.5'9/16.0

END IF

'Ensure last position is at slot 42 
 PVD(j,N_steps(j)).Zp=42

'FOR i = 0 TO N_steps(j)
'	FORMAT PrintString, "%d,%.2f,%.2f,%.2f,%.2f\r",
'		INTV:i,DBLV:PVD(j,i).Zp,DBLV:PVD(j,i).Zv,DBLV:PVD(j,i).Sp,DBLV:PVD(j,i).Sv
'	flag = PVD(j,i).Zp
'	IF flag > -1 THEN
'		PRINT PrintString
'	END IF
'NEXT i	
 NEXT j

END FUNCTION

FUNCTION Flythru()
'Fly-thru Mode: j = 5
'	N_steps = 2 + 40 + 2 = 44
'	2 steps to move from slot 0 to 1; 2 steps to move from slot 41 to 42
DIM i AS INTEGER,j AS INTEGER
j=5
FOR i=2 TO 42' Assign positions and velocities for 41 slots
PVD(j,i).X=1
PVD(j,i).L=1
PVD(j,i).Zp=i-1
PVD(j,i).Zv=1
PVD(j,i).Sp=0
NEXT i
PVD(j,44).Zp=42
PVD(j,44).Sp=-1

'FOR i = 0 TO N_steps(j)
'	FORMAT PrintString, "%d,%.2f,%.2f,%.2f,%.2f\r",
'		INTV:i,DBLV:PVD(j,i).Zp,DBLV:PVD(j,i).Zv,DBLV:PVD(j,i).Sp,DBLV:PVD(j,i).Sv
'	flag = PVD(j,i).Zp
'	IF flag > -1 THEN
'		PRINT PrintString
'	END IF
'NEXT i

END FUNCTION

FUNCTION Flythru_LCLS()
'Fly-thru Mode: j = 5
'	N_steps = 2 + 80 + 2 = 84
'		2 steps to move from slot 0 to 1
'		80 steps to move from slot 1 to 41
'		2 steps to move from slot 41 to 42
DIM i AS INTEGER,j AS INTEGER
j=9
FOR i=2 TO 86 STEP 2' Assign positions and velocities for 41 slots
PVD(j,i).X=1
PVD(j,i).L=1
PVD(j,i).Zp=i/2
PVD(j,i).Zv=0.5
PVD(j,i).Sp=0
NEXT i
PVD(j,84).Zp=42
PVD(j,84).Zv=0
PVD(j,84).Sp=-1

'FOR i = 0 TO N_steps(j)
'	FORMAT PrintString, "%d,%.2f,%.2f,%.2f,%.2f\r",
'		INTV:i,DBLV:PVD(j,i).Zp,DBLV:PVD(j,i).Zv,DBLV:PVD(j,i).Sp,DBLV:PVD(j,i).Sv
'	flag = PVD(j,i).Zp
'	IF flag > -1 THEN
'		PRINT PrintString
'	END IF
'NEXT i

END FUNCTION

FUNCTION PP_Array()
'Estimate Peristaltic Pump position using 5th order polynomial
 DIM i AS INTEGER
FOR i=0 TO 99' Assign positions for 100 steps
v=i*24.699999999999999/99
PP(i)=1.843*v-0.0066010000000000001*v^2+0.0038279999999999998*v^3-0.00043209999999999999*v^4+1.1590000000000001e-005*v^5
NEXT i
END FUNCTION
