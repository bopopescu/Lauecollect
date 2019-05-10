' ------------------------------------------------ 
' --------------- PVT_250Hz_FastReturn.ab -----------------
' ------------------------------------------------ 
'
'
'velocity is ~150 mm/ms
'

DGLOBAL(3)=1'mode of operation
 DGLOBAL(0)=0'time offset to synchronize
 DGLOBAL(1)=0'counter for computing <PMCD(Z)>

'User input (Z_1, PumpA_step)
 Z_41=12.75'slot 41 position 
 DZ=0.60999999999999999'slot separation
 Nslots=41
PumpA_step=1
DT=0.0040507596666666664'~250 Hz

'DT = 0.999998412*DT 'oscillator correction relative to Ramsey RF (351.93398 MHz)
 DT=1.00023*DT'oscillator correction for DG535 (0.866 Hz)
 Z_1=Z_41-( Nslots-1)*DZ'slot 1 position
 Z_mid=Z_41-0.5*( Nslots-1)*DZ'mid-point of the stroke
 Z_end=Z_41+0.5*DZ' end-point of the stroke
Z_start=Z_41-( Nslots-0.5)*DZ
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
IF NOT homed THEN'make sure axis is homed
HOME 2
 END IF
MOVEABS 2:Z_end 'Go to starting position
WAIT MOVEDONE 2

DOUT:0::1, 0:0'Ensure digital output is low when starting

'Find current position of PumpA
 PumpA_0=PCMD(4)

'Set up for PVT calls
 ABS'Positions specified in absolute coordinates
PVT_INIT  @1 
 HALT

WHILE DIN:0::( 1,0)=0'wait for clk pulse 
 DWELL 0.00025000000000000001
WEND
DGLOBAL(1)=0'reset PLL counter
 SCOPETRIG'Requires 0.008 s to execute?

DWELL((277)*DT-0.0089999999999999993)'DWELL time to phase the start of the Z motion

j=0
PVT 2: Z_end, 0,4: PumpA_0, 0 @0.001 |DOUT 0:1, 0,1 
WHILE DGLOBAL(3)>0'insert IF statements to select mode; mode 0 ends  motion
 PumpA_pos=PumpA_0+j*PumpA_step
T_0=15*DT+j*(285)*DT+DGLOBAL(0)'285*DT -> 0.866 Hz
FOR i=0 TO Nslots+1
Zi=Z_1+( i-1)*DZ
Ti=T_0+6*i*DT
IF i=0 THEN
PVT 2: Z_start, 0,4: PumpA_pos, 0 @Ti |DOUT 0:1, 0,1 
ELSEIF i=Nslots+1 THEN
PVT 2: Z_end, 0,4: PumpA_pos, 0 @Ti |DOUT 0:1, 1,1 
PVT 2: Z_end, 0,4: PumpA_pos, 0 @( Ti+18*DT) |DOUT 0:1, 0,1 
ELSE
PVT 2: Zi, 0,4: PumpA_pos, 0 @( Ti-3*DT) |DOUT 0:1, 1,1 
PVT 2: Zi, 0,4: PumpA_pos, 0 @Ti |DOUT 0:1, 1,1 
END IF
NEXT i

'FORMAT PrintString, "%d,%.3f,%.3f,%.3f,%.3f\n",
'INTV:j,DBLV:T_1,DBLV:T_2,DBLV:T_3,DBLV:T_4
'PRINT PrintString
'FORMAT PrintString, "%d,%.3f,%.3f,%.3f,%.3f\n",
'INTV:j,DBLV:Z_1,DBLV:Z_2,DBLV:Z_3,DBLV:Z_4
'PRINT PrintString


'correct phase every 64 repeats (if err > 5 um)

IF(j<>0)AND(j/64-FLOOR(j/64))=0
THEN
pos_err=DGLOBAL(2)-Z_mid+0.40000000000000002
IF ABS(pos_err)>0.0030000000000000001
THEN'divide pos_err by Vmax -> 616 mm/s during back stroke
 DGLOBAL(0)=DGLOBAL(0)-pos_err/617
END IF
DGLOBAL(1)=0
FORMAT PrintString,"%d,%.3f,%.5f\r",
INTV:j,DBLV:pos_err,DBLV:DGLOBAL(0)
PRINT PrintString
END IF

'FORMAT PrintString, "%d\n", INTV:j
'PRINT PrintString
 j=j+1
WEND
MOVEABS 2:Z_1 'Go to first slot
