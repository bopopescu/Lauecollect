' ------------------------------------------------ 
' --------------- PVT_250Hz_FastReturn.ab -----------------
' ------------------------------------------------ 
'
'
'velocity is ~150 mm/ms
'


DGLOBAL(0)=0'time offset to synchronize
 DGLOBAL(1)=0'counter for computing <PMCD(Z)>

Z_0=12.94'13.19 'starting Z position
DZ=0.60999999999999999'slot separation
 DT=0.0040507596666666664'~250 Hz
DT=0.99999841199999995*DT'oscillator correction
 Nslots=41

Vn=-1*DZ/DT'velocity of sample cell

'Z_synch = Z_0-0.3 'synch location

SCOPETRIG
DWELL 0.0030000000000000001


'SETGAIN <Axis>, <GainKp>, <GainKi>, <GainKpos>, <GainAff>
'SETGAIN sets all 4 parameters synchronously
SETGAIN 2:1780000, 10000,100,56200 
SETPARM 2: GainVff, 2371 

DIM PrintString AS STRING(80)

POSOFFSET SET 4:0 
SETEXTPOS 4:0 
 PumpA_0=PCMD(4)

'Initial setup
 IF AXISFAULT(2)<>0 THEN
FAULTACK 2'Make sure any fault state is cleared.
END IF
ENABLE 2
DIM homed AS INTEGER
homed=(AXISSTATUS(2) >> 1) BAND 1
IF NOT homed THEN'make sure axis is homeds
HOME 2
 END IF
MOVEABS 2: Z_0-( Nslots-0.5)*DZ ' + DZ 'Got to starting position
WAIT MOVEDONE 2

'RAMP TIME PumpA 0.038
'RAMP RATE PumpA 820000

ABS'Positions specified in absolute coordinates
PVT_INIT  @1 
 HALT

WHILE DIN:0::( 1,0)=0'wait for clk pulse 
 DWELL 0.00025000000000000001
WEND

DWELL 0.252



PVT 2:(Z_0-(Nslots-0.5)*DZ),0,4:0, 0 @0.0001 |DOUT 0:1, 0,1 

j=0
WHILE 1
PumpA_pos=PumpA_0+j*45
T_0=15*DT+j*57*DT+DGLOBAL(0)' 57 -> 4.33 Hz
FOR i=-1TO Nslots
Ti=T_0+( i+1)*DT
Zi=Z_0-i*DZ
IF i=-1
THEN
PVT 2: Zi, 0,4: PumpA_pos, 0 @Ti |DOUT 0:1, 1,1 
ELSEIF i=Nslots
THEN
PVT 2: Zi, 0,4: PumpA_pos, 0 @Ti |DOUT 0:1, 0,1 
IF j=0 THEN
DGLOBAL(1)=0'reset PLL counter
 END IF
ELSE
PVT 2: Zi, Vn,4: PumpA_pos, 0 @Ti |DOUT 0:1, 1,1 

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
pos_err=DGLOBAL(2)
IF ABS(pos_err)>0.0030000000000000001
THEN'divide pos_err by Vmax
 DGLOBAL(0)=DGLOBAL(0)+pos_err/606
END IF
DGLOBAL(1)=0
FORMAT PrintString,"%d,%.3f,%.5f\r",
INTV:j,DBLV:DGLOBAL(2),DBLV:DGLOBAL(0)
PRINT PrintString
END IF

'FORMAT PrintString, "%d\n", INTV:j
'PRINT PrintString
 j=j+1
WEND
