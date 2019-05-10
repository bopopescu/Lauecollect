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
'GLOBAL PP() AS SINGLE = {0,0.7,1.4,1.95,2.5,3.05,3.6,4.05,4.5,4.95,5.4,5.85,6.3,6.75,7.2,7.6,8,8.4,8.8,9.25,9.7,10.1,10.5,10.9,11.3,11.7,12.1,12.55,13,13.4,13.8,14.2,14.6,15,15.4,15.8,16.2,16.65,17.1,17.5,17.9,18.3,18.7,19.1,19.5,19.9,20.3,20.75,21.2,21.25,21.6,22,22.4,22.8,23.2,23.6,24,24.4,24.75,25.1,25.5,25.9,26.3,26.7,27.1,27.5,27.9,28.3,28.65,29,29.4,29.8,30.2,30.6,30.95,31.3,31.7,32.1,32.5,32.9,33.3,33.7,34.1,34.5,34.9,35.3,35.75,36.2,36.65,37.1,37.55,38,38.5,39,39.5,40,40.6,41.2,41.85,42.5,43.1}
'PP is peristaltic pump vector that linearizes volume dispensed over a 50 step stroke
 GLOBAL PP(100)AS SINGLE
END DECLARATIONS

 PROGRAM 
'Test of new fly-thru mode\
 CALL PP_Array()
Npp=0
WHILE Npp<500
PumpA_pos=50*FLOOR(Npp/100)+PP(Npp-100*FLOOR(Npp/100))
Npp=Npp+1
DWELL 1
WEND

END PROGRAM 

FUNCTION PP_Array()
'Estimate Peristaltic Pump position using 5th order polynomial
 DIM i AS INTEGER
FOR i=0 TO 99' Assign positions for 100 steps
v=i*24.699999999999999/99
PP(i)=1.843*v-0.0066010000000000001*v^2+0.0038279999999999998*v^3-0.00043209999999999999*v^4+1.1590000000000001e-005*v^5
NEXT i
END FUNCTION
