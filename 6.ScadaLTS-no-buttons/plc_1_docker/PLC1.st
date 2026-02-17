PROGRAM PLC1
  VAR
    level AT %IW0 : INT;
    pump AT %QX0.0 : BOOL;
    valve AT %QX0.1 : BOOL;
    request AT %QX0.2 : BOOL;
    underflow AT %QX0.3 : BOOL;
    overflow AT %QX0.4 : BOOL;
    low_1 AT %MW1 : INT := 40;
    high_1 AT %MW2 : INT := 80;
  END_VAR

  underflow := LE(level, low_1);
  overflow := GE(level, high_1);
  pump := NOT(overflow) AND (underflow OR pump);
  valve := request AND (NOT(underflow) OR valve);
  
END_PROGRAM

CONFIGURATION Config0

  RESOURCE Res0 ON PLC
    TASK task0(INTERVAL := T#20ms,PRIORITY := 0);
    PROGRAM instance0 WITH task0 : PLC1;
  END_RESOURCE
END_CONFIGURATION
