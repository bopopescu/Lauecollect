' ------------------------------------------------ 
' --------------- PVT_250Hz_FastReturn.ab -----------------
' ------------------------------------------------ 
'
'
'velocity is ~150 mm/ms
'

DGLOBAL(3)=2'default mode of operation
 mode_current=DGLOBAL(3)
DGLOBAL(0)=0'time offset
 DGLOBAL(1)=0'counter for computing <PMCD(Z)>

'User input (Z_1, PumpA_step)
 Z_41=12.91'slot 41 position 
 PumpA_step=1.8'45/24

DZ=0.60999999999999999'slot separation
 Nslots=41
Z_1=Z_41-( Nslots-1)*DZ'slot 1 position
 Z_mid=Z_41-0.5*( Nslots-1)*DZ'mid-point of the stroke
 Z_end=Z_41+0.5*DZ' end-point of the stroke
Z_start=Z_41-( Nslots-0.5)*DZ

DT=0.0040507596666666664'~250 Hz; 1100 subharmonic of P0
'DT = 0.999998412*DT 'oscillator correction relative to Ramsey RF (351.93398 MHz)
 DT=1.0002306999999999*DT'oscillator correction for DG535 (0.866 Hz)
 Vn=DZ/DT'velocity of sample cell

'SETGAIN <Axis>, <GainKp>, <GainKi>, <GainKpos>, <GainAff>
'SETGAIN sets all 4 parameters synchronously
'SETGAIN Z, 1780000, 10000, 56.2, 56200 original settings
SETGAIN 2:1780000, 10000,56.200000000000003,56200 
SETPARM 2: GainVff, 0 

DIM PrintString AS STRING(80)

'Initial setup for Z axis
 IF AXISFAULT(2)<>0 THEN
FAULTACK 2'Make sure any fault state is cleared.
END IF
ENABLE 2
DIM homed AS INTEGER
homed=(AXISSTATUS(2) >> 1) BAND 1
IF NOT homed THEN'make sure axis is homeds
HOME 2
 END IF
MOVEABS 2:Z_end 'move to end of stroke position
WAIT MOVEDONE 2

DOUT:0::1, 0:0'Ensure digital output is low when starting

'Find current position of PumpA
 PumpA_pos=PCMD(4)

'Set up for PVT calls
 ABS'Positions specified in absolute coordinates
PVT_INIT  @1 
 HALT

WHILE DIN:0::( 1,0)=1'wait until low
 DWELL 0.00025000000000000001
WEND
WHILE DIN:0::( 1,0)=0'wait until high  
 DWELL 0.00025000000000000001
WEND
WHILE DIN:0::( 1,0)=1'wait until low
 DWELL 0.00025000000000000001
WEND

PVT 2: Z_end, 0,4: PumpA_pos, 0 @0.001 |DOUT 0:1, 0,1 
FOR i=1 TO 11
Ti=i*DT
PVT 2: Z_end, 0,4: PumpA_pos, 0 @Ti |DOUT 0:1, 0,1 
NEXT i
DWELL 0.002
T_0=285*DT+0.01575
PVT 2: Z_end, 0,4: PumpA_pos, 0 @( T_0-15*DT) |DOUT 0:1, 0,1 
PVT 2: Z_start, 0,4: PumpA_pos, 0 @T_0 |DOUT 0:1, 0,1 

DWELL 1
SCOPETRIG

j=0
WHILE DGLOBAL(3)>-1'insert IF statements to select mode; mode 1 pauses motion
 WHILE DIN:0::( 1,0)=0'wait for clk pulse 
 DWELL 0.00025000000000000001
WEND
STARTSYNC 2'query DIN(X,1,0) every 2 ms to measure the pulse width (N_mode)
 Zpos=PCMD(2)
N_mode=0
FOR i=1 TO 4
SYNC
N_mode=N_mode+DIN:0::( 1,0)
NEXT i

IF N_mode=2 THEN
REPEAT 5
FOR i=1 TO Nslots
Zi=Z_1+( i-1)*DZ
Ti=T_0+i*DT
IF i=Nslots THEN
PVT 2: Zi, Vn,4: PumpA_pos, 0 @Ti |DOUT 0:1, 1,1 
PVT 2: Z_end, 0,4: PumpA_pos, 0 @Ti+DT |DOUT 0:1, 0,1 
PumpA_pos=PumpA_pos+PumpA_step
PVT 2: Z_start, 0,4: PumpA_pos, 0 @Ti+16*DT |DOUT 0:1, 0,1 
ELSE
PVT 2: Zi, Vn,4: PumpA_pos, 0 @Ti |DOUT 0:1, 1,1 
END IF
NEXT i
T_0=T_0+57*DT
ENDREPEAT
ELSEIF N_mode=1 THEN
FOR i=1 TO Nslots
Zi=Z_1+( i-1)*DZ
Ti=T_0+6*i*DT
IF i=Nslots THEN
PVT 2: Zi, 0,4: PumpA_pos, 0 @( Ti-3*DT) |DOUT 0:1, 1,1 
PVT 2: Zi, 0,4: PumpA_pos, 0 @Ti |DOUT 0:1, 1,1 
PVT 2: Z_end, 0,4: PumpA_pos, 0 @( Ti+3*DT) |DOUT 0:1, 0,1 
PVT 2: Z_end, 0,4: PumpA_pos, 0 @( T_0+(270)*DT) |DOUT 0:1, 0,1 
PumpA_pos=PumpA_pos+PumpA_step
PVT 2: Z_start, 0,4: PumpA_pos, 0 @( T_0+(285)*DT) |DOUT 0:1, 0,1 
ELSE
PVT 2: Zi, 0,4: PumpA_pos, 0 @( Ti-3*DT) |DOUT 0:1, 1,1 
PVT 2: Zi, 0,4: PumpA_pos, 0 @Ti |DOUT 0:1, 1,1 
END IF
NEXT i
T_0=T_0+285*DT'+DGLOBAL(0) '285*DT -> 0.866 Hz
ELSE
PVT 2: Z_1, 0,4: PumpA_pos, 0 @( T_0+DT) |DOUT 0:1, 0,1 
PVT 2: Z_1, 0,4: PumpA_pos, 0 @( T_0+(270)*DT) |DOUT 0:1, 0,1 
PVT 2: Z_start, 0,4: PumpA_pos, 0 @( T_0+285*DT) |DOUT 0:1, 0,1 
T_0=T_0+285*DT'+DGLOBAL(0)
END IF

'FORMAT PrintString, "%d,%.3f,%.3f,%.3f,%.3f\n",
'INTV:j,DBLV:T_1,DBLV:T_2,DBLV:T_3,DBLV:T_4
'PRINT PrintString
'FORMAT PrintString, "%d,%.3f,%.3f,%.3f,%.3f\n",
'INTV:j,DBLV:Z_1,DBLV:Z_2,DBLV:Z_3,DBLV:Z_4
'PRINT PrintString


'If necessary, correct phase by tweaking T0
 IF(N_mode=1)OR(N_mode=2)THEN
IF j=0 THEN
Zpos_sum=0
Zpos_sumsq=0
counter=1
END IF

Zpos_sum=Zpos_sum+Zpos
Zpos_sumsq=Zpos_sumsq+Zpos^2
stdev=sqr(Zpos_sumsq/counter-( Zpos_sum/counter)^2)
pos_err=Zpos_sum/counter-Z_mid+0.34000000000000002
counter=counter+1

IF(counter>32)AND(abs(pos_err)>2*(stdev/sqr(counter)))THEN
FORMAT PrintString,"%d,%.3f,%.5f,%.5f\r",
INTV:counter,DBLV:pos_err,DBLV:stdev,DBLV:pos_err/617
PRINT PrintString
T_0=T_0-pos_err/617'divide pos_err by Vmax -> 617 mm/s during back stroke
 Zpos_sum=0
Zpos_sumsq=0
counter=1
END IF
END IF
'FORMAT PrintString, "%d,%.3f,%.3f,\n", INTV:counter,DBLV:pos_err,DBLV:stdev
'PRINT PrintString

j=j+1
WEND
MOVEABS 2:Z_1 'Go to first slot
