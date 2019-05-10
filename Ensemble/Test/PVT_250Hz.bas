' ------------------------------------------------ 
' --------------- PVT_250Hz.ab -----------------
' ------------------------------------------------ 
'
' This program moves rapidly back and forth. 
'
'synchronize at 12.28 mm?
'velocity is 301.178 mm/ms
'

DGLOBAL(0)=0'time offset to synchronize
 DGLOBAL(1)=0'counter for computing <PMCD(Z)>

Z_0=13.19'12.58 'starting Z position
DZ=0.60999999999999999'slot separation
 DT=0.0040507596666666664'~250 Hz
Nslots=41

Vp=2*DZ/DT'velocity of sample cell
 Vn=-1*Vp
DT=0.99999841199999995*DT
Z_synch=Z_0-0.29999999999999999'synch location



'SETGAIN <Axis>, <GainKp>, <GainKi>, <GainKpos>, <GainAff>
'SETGAIN sets all 4 parameters synchronously
SETGAIN 2:1780000, 10000,100,56200 
SETPARM 2: GainVff, 2371 

DIM PrintString AS STRING(80)

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
MOVEABS 2:Z_0+1.2 'Got to starting position
WAIT MOVEDONE 2

ABS'Positions specified in absolute coordinates.s
PVT_INIT  @1 
 HALT

WHILE DIN:0::( 1,0)=0'wait for clk pulse 
 DWELL 0.00025000000000000001
WEND
DWELL 0.98060000000000003'0.971, 0.980 with Task 1 only

j=0
WHILE 1
T_0=j*47*DT+DGLOBAL(0)
FOR i=0 TO Nslots-1
IF i<21
THEN
Zi=Z_0-2*i*DZ
Ti=T_0+( i+0.5)*DT
IF(i=0)OR(i=20)
THEN
PVT 2: Zi, Vn @Ti |DOUT 0:1, 0,1 
ELSE
PVT 2: Zi, Vn @Ti |DOUT 0:1, 1,1 
END IF
ELSE
Zi=Z_0-(2*(Nslots-i)-1)*DZ
Ti=T_0+( i+3.5)*DT
IF(i=40)OR(i=21)
THEN
PVT 2: Zi, Vp @Ti |DOUT 0:1, 0,1 
ELSE
PVT 2: Zi, Vp @Ti |DOUT 0:1, 1,1 
END IF
END IF
NEXT i

'FORMAT PrintString, "%d,%.3f,%.3f,%.3f,%.3f\n",
'INTV:j,DBLV:T_1,DBLV:T_2,DBLV:T_3,DBLV:T_4
'PRINT PrintString
'FORMAT PrintString, "%d,%.3f,%.3f,%.3f,%.3f\n",
'INTV:j,DBLV:Z_1,DBLV:Z_2,DBLV:Z_3,DBLV:Z_4
'PRINT PrintString


'correct phase every 64 repeats (if err > 5 um)

'	IF (j/64 - FLOOR(j/64)) = 0
'		THEN
'			pos_err = DGLOBAL(2)-Z_synch
'			IF ABS(pos_err) > 0.003
'				THEN 
'					offset = pos_err/75
'					DGLOBAL(0) = DGLOBAL(0)+ pos_err/75
'			END IF
'			DGLOBAL(1) = 0
'	END IF

'FORMAT PrintString, "%d\n", INTV:j
'PRINT PrintString
 j=j+1
WEND
