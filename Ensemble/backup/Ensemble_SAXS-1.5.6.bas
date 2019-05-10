' version 1.5.6
DECLARATIONS

TYPE PVT_parameters
Zp AS SINGLE'32-bit single-precision float
Zv AS SINGLE
Sp AS SINGLE
Sv AS SINGLE
L AS INTEGER
X AS INTEGER
D AS INTEGER
END TYPE

GLOBAL N_steps()AS INTEGER={249,2405,375,189,174,45,249,372,618}
GLOBAL PVD(8,618)AS PVT_parameters
GLOBAL PP()AS SINGLE={0,1.3999999999999999,2.5,3.6000000000000001,4.5,5.4000000000000004,6.2999999999999998,7.2000000000000002,8,8.8000000000000007,9.6999999999999993,10.5,11.300000000000001,12.1,13,13.800000000000001,14.6,15.4,16.199999999999999,17.100000000000001,17.899999999999999,18.699999999999999,19.5,20.300000000000001,21.199999999999999,22,22.800000000000001,23.600000000000001,24.399999999999999,25.100000000000001,25.899999999999999,26.699999999999999,27.5,28.300000000000001,29,29.800000000000001,30.600000000000001,31.300000000000001,32.100000000000001,32.899999999999999,33.700000000000003,34.5,35.299999999999997,36.200000000000003,37.100000000000001,38,39,40,41.200000000000003,42.5}

END DECLARATIONS

 PROGRAM 

DIM PrintString AS STRING(80)
DIM N_mode AS INTEGER
DIM Di AS INTEGER
DIM Itemp AS INTEGER

DGLOBAL(0)=0' Use to keep While Loop running (-1 finishes execution)
DGLOBAL(1)=1' PumpA_step displaced during return stroke
DGLOBAL(2)=20'# x-ray pulses transmitted in Idle mode (even number)

' Initialize Zp and Sp
FOR j=0 TO 8
FOR i=0 TO 618
PVD(j,i).Zp=-1' -1 is a flag to suppress PVT commands
PVD(j,i).Sp=-1' -1 is the normal closed state (close1)
NEXT i
NEXT j

'	Call functions to specify paramters required for the respective modes
CALL Exotic()
CALL Stepping()
CALL Flythru()

Plane 1
'RECONCILE Z PumpA msShut_ext
RECONCILE 2,6

T_offset=0'0.65 'time offset in units of DT; centers msShut_ext opening on x-ray pulse

'Timing parameters (rescale DT to approximately match the source frequency)
 DT=0.0010126899166666666'~1000 Hz; 275th subharmonic of P0
'DT = 0.9999949*DT ' 06.06.2015 correction to match APS frequency; was 0.9999953
 DT=0.99999570000000004*DT' 10.27.2015 correction to match APS frequency
'DT = 1.0000039*(351.933/350.000)*DT 'FPGA internal oscillator for Pico23
'DT = 0.9999962*(351.933/350.000)*DT 'FPGA internal oscillator for Pico24

'Slotted Sample Cell parameters
 Nslots=41
DZ=0.60999999999999999'slot separation
 Z_1=-11.359' at APS; slot 1 position w/ cooling water set to 10 Celsius.
'Z_1 = -11.4 ' at NIH
 Z_start=Z_1-DZ
Z_end=Z_start+( Nslots+1)*DZ' end-point of the stroke
Z_mid=Z_start+0.5*( Nslots+1)*DZ'mid-point of the stroke
 Z_v=DZ/(4*DT)'velocity of sample cell in fly-thru mode (~150 mm/s)
 Z_vmax=1.5*(Nslots+1)*DZ/(60*DT)'Z velocity at midpoint of return stroke (mm/s)

'Axis Z parameters
'SETGAIN <Axis>, <GainKp>, <GainKi>, <GainKpos>, <GainAff>
'SETGAIN sets all 4 parameters synchronously
SETGAIN 2:1780000, 10000,56.200000000000003,56200 'original settings
SETPARM 2: GainVff, 0 'original setting
'SETGAIN Z, 1780000, 7500, 133, 5620 'New settings
'SETPARM Z, GainVff, 3162

'Millisecond shutter parameters; determined at BioCARS in Feb 2015
'SETGAIN msShut_ext, 180900, 2621, 59, 260700
'SETPARM msShut_ext, GainVff, 5932

'Find current position of Z, msShut, and PumpA
 Z_pos=PCMD(2)
msShut_current=PCMD(6)
'PumpA_pos = PLANEPOS(PumpA)

HOME 4
Npp=0
PumpA_pos=0

'Set up ms shutter parameters; ensure msShut is set to close1.
 msShut_open=9.6999999999999993' Measured 03.06.2015; was 9.99 'Angle at center of opening
msShut_step=10'14.58 '(was 8.77) 'Step angle to open/close the shutter
msShut_close1=msShut_open-msShut_step
msShut_close2=msShut_open+msShut_step


DOUT:0::1, 0'Ensure all bits of digital output are low when starting

'Set up for PVT calls
 ABS'Positions specified in absolute coordinates
PVT_INIT  @1 
 VELOCITY ON
HALT

'Wait for start of pulse pattern to synchronize start of motion
 WHILE DIN:0::( 1,0)=0'wait for next low-to-high transition.
 DWELL 0.00025000000000000001
WEND
DWELL 0.029999999999999999'wait till after burst is over (30 ms is more than enough.
 WHILE DIN:0::( 1,0)=0'wait for next low-to-high transition.
 DWELL 0.00025000000000000001
WEND

'query DIN(X,1,0) every 2 ms to determine the mode of operation (msShut_Enable, PumpA_Enable, and N_mode)
 STARTSYNC 2
SYNC
msShut_Enable=DIN:0::( 1,0)
SYNC
PumpA_Enable=DIN:0::( 1,0)
N_mode=0
FOR i=0 TO 4
SYNC
N_mode=N_mode+DIN:0::( 1,0)*2^i
NEXT i
Last_Mode=N_mode

'Synchronize start (timing is mode dependent).

T_0=((N_steps(N_mode)+15)*4+8)*DT' +10 [ms] is offset to properly synchronize the start 
Scope_Trigger_Delay=T_0-0.10000000000000001' Start recording 100 ms before the start of the scan.
Npts=8*N_steps(N_mode)+400
SCOPETRIGPERIOD-2' 0.5 ms per point
SCOPEBUFFER(200*CEIL(Npts/200))'Round up to nearest 100 ms

'Move motors into position to start.
PVT 2: Z_pos, 0,4: PumpA_pos, 0,6: msShut_current, 0 @0.001 |DOUT 0:1, 0,1 
PVT 2: Z_end, 0,4: PumpA_pos, 0,6: msShut_close1, 0 @( T_0-60*DT) |DOUT 0:1, 0,1 
PVT 2: Z_start, 0,4: PumpA_pos, 0,6: msShut_close1, 0 @T_0 |DOUT 0:1, 0,1 
 START

DWELL Scope_Trigger_Delay'Delay to synchronize scope near the start of the scan.
 SCOPETRIG

k=0
WHILE DGLOBAL(0)>-1'enter DGLOBAL(0) = -1 to exit loop
 WHILE DIN:0::( 1,0)=0'wait for clk pulse 
 DWELL 0.00025000000000000001
WEND

'Decode N_mode from trigger pulse train
 STARTSYNC 2'query DIN(X,1,0) every 2 ms 
 Zpos=PCMD(2)
msShut_current=PCMD(6)
SYNC
msShut_Enable=DIN:0::( 1,0)
SYNC
PumpA_Enable=DIN:0::( 1,0)
N_mode=0
FOR i=0 TO 4
SYNC
N_mode=N_mode+DIN:0::( 1,0)*2^i
NEXT i
j=N_mode

Svmax=2*msShut_step/(8*DT)'Max S velocity is 2 time the average velocity
 Zvmax=DZ/(4*DT)'Max Z velocity for Exotic and Fly-thru Modes
 IF j>5 THEN
Zvmax=2*DZ/(12*DT)'Max Z velocity for Stepping Modes
 END IF

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
PumpA_pos=50*FLOOR(Npp/50)+PP(Npp-50*FLOOR(Npp/50))
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
T_0=T_0+( N_steps(j)+15)*4*DT
PVT 6: msShut_close1, 0 @T_0 |DOUT 0:1, 1,15 
'RECONCILE Z PumpA msShut_ext	
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

' Correct phase if necessary
IF(Last_Mode=N_mode)AND(N_mode>0)THEN
IF k=0 THEN
Zpos=0
Zpos_sum=0
Zpos_sumsq=0
counter=1
END IF

Zpos_sum=Zpos_sum+Zpos
Zpos_sumsq=Zpos_sumsq+Zpos^2
stdev=sqr(Zpos_sumsq/counter-( Zpos_sum/counter)^2)
pos_err=Zpos_sum/counter-Z_mid+0.434+T_offset*DT*Z_vmax'tweaked to 0.434 to center rising edge on central slot
 counter=counter+1
IF(counter>32)AND(abs(pos_err)>2*(stdev/sqr(counter)))THEN
FORMAT PrintString,"%d,%.3f,%.5f,%.5f\r",
INTV:counter,DBLV:pos_err,DBLV:stdev,DBLV:pos_err/Z_vmax
PRINT PrintString
T_correction=pos_err/Z_vmax'divide pos_err by Z_vmax to convert to time
 T_max=0.0040000000000000001
IF(T_correction>T_max)THEN
T_correction=T_max
ELSEIF(T_correction<-1*T_max)THEN
T_correction=-1*T_max
END IF
T_0=T_0-T_correction
Zpos_sum=0
Zpos_sumsq=0
counter=1
END IF
END IF

'FORMAT PrintString, "%d,%.3f,%.3f,\n", INTV:N_mode,DBLV:pos_err,DBLV:stdev
'PRINT PrintString
 Last_Mode=N_mode
k=k+1
WEND

LINEAR 4:50*(FLOOR(Npp/50)+1) @10 
END PROGRAM 

FUNCTION Stepping()
'Stepping Modes: j = 6 to 8 -> [12,24,48] ms dwell times
'	N_steps = 41*3*(2^N+1)+3; N = [0,1,2] -> [249,372,618] steps
DIM PrintString AS STRING(80)
For j=6 TO 8
N=j-6
Nperiod=3*(2^N+1)' # steps between xray pulses
PVD(j,0).Zp=-1'Flag to suppress PVT command
 PVD(j,1).Zp=-1
X_count=0
FOR i=2 to N_steps(j)
IF FLOOR(i/Nperiod)=CEIL(i/Nperiod)THEN
'FORMAT PrintString, "%d\r",INTV:i
'PRINT PrintString
 k=3*2^N
X_count=X_count+1
PVD(j,i).X=X_count
PVD(j,i).L=X_count
PVD(j,i-k).Zp=X_count
PVD(j,i-2).Zp=X_count
PVD(j,i).Zp=X_count
PVD(j,i+2).Zp=X_count+0.7407407407407407
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
NEXT j

END FUNCTION

FUNCTION Exotic()
'Exotic Modes: j = 2 to 4 -> [32.4,64.8,129.6] ms delay times
'	N = [0,1,2] -> [375,189,174] steps

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
PVD(j,i).Sp=0
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
IF N=0 THEN
PVD(j,i+2).Zp=PVD(j,i+1).Zp+0.75
PVD(j,i+2).Zv=0.5
slot=PVD(j,i).Zp
IF CEIL(slot/2)=FLOOR(slot/2)THEN' if even						
PVD(j,i-2).Sp=-1
PVD(j,i+1).Sp=0.84375
PVD(j,i+2).Sp=1
PVD(j,i+3).Sp=1
PVD(j,i).Sv=1
PVD(j,i+1).Sv=0.5625
ELSE' if odd
PVD(j,i-2).Sp=1
PVD(j,i+1).Sp=-0.84375
PVD(j,i+2).Sp=-1
PVD(j,i+3).Sp=-1
PVD(j,i).Sv=-1
PVD(j,i+1).Sv=-0.5625
END IF
ELSE
PVD(j,i+1).Sp=-0.5
PVD(j,i+1).Sv=-1
END IF
END IF

Ll=PVD(j,i).L
IF Ll=41 THEN
IF N=1 THEN
PVD(j,i+2).Zp=42
PVD(j,i+1).Zp=41.75
PVD(j,i+1).Zv=0.5
ELSE
PVD(j,N_steps(j)-2).Zp=42
END IF
END IF
Xi=PVD(j,i).X
IF Xi=41 THEN
PVD(j,i+2).Zp=PVD(j,i).Zp+1
IF N=0 THEN
PVD(j,N_steps(j)-1).Zp=44
PVD(j,i+1).Zv=0
END IF
END IF
NEXT i

IF N=0 THEN
' First move Sp from -1 to 1 in 3 steps (without transmitting xray pulse)
PVD(j,2).Sp=0.48148148148148145' 2*20/27 - 1
PVD(j,3).Sp=1
PVD(j,4).Sp=1
PVD(j,2).Sv=0.88888888888888884' 4/3 * 2/3
PVD(j,3).Zp=1.75'27/32.0
PVD(j,3).Zv=0.5'9/16.0

' Assign appropriate Z velocity for last close 
PVD(j,N_steps(j)-3).Zv=0
END IF

PVD(j,N_steps(j)-1).Zp=42' Ensure last position is at slot 42
NEXT j

END FUNCTION

FUNCTION Flythru()
'Fly-thru Mode: j = 5 
'	N_steps = 41 + 4 = 45
'	2 steps to move from slot 0 to 1; 2 steps to move from slot 41 to 42
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
PVD(j,45).Zp=42
PVD(j,45).Sp=-1
END FUNCTION

