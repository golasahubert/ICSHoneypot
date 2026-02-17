PROGRAM PLC3
  VAR
    level AT %IW0 : INT;
    pump AT %QX0.0 : BOOL;
    low AT %QX0.1 : BOOL;
    high AT %QX0.2 : BOOL;
    low_3 AT %MW1 : INT := 0;
    high_3 AT %MW2 : INT := 3;
  END_VAR

  low := LE(level, low_3);
  high := GE(level, high_3);
  pump := NOT(low) AND (high OR pump);
  
END_PROGRAM

CONFIGURATION Config0

  RESOURCE Res0 ON PLC
    TASK task0(INTERVAL := T#20ms,PRIORITY := 0);
    PROGRAM instance0 WITH task0 : PLC3;
  END_RESOURCE
  
END_CONFIGURATION
