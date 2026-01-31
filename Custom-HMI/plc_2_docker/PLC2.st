PROGRAM PLC2
  VAR
    level AT %IW0 : INT;
    request AT %QX0.0 : BOOL;
    open_req AT %QX0.1 : BOOL;
    close_req AT %QX0.2 : BOOL;
    low_2 AT %MW1 : INT := 10;
    high_2 AT %MW2 : INT := 20;
  END_VAR

  open_req := LE(level, low_2);
  close_req := GE(level, high_2);
  request := NOT(close_req) AND (open_req OR request);
  
END_PROGRAM

CONFIGURATION Config0

  RESOURCE Res0 ON PLC
    TASK task0(INTERVAL := T#20ms,PRIORITY := 0);
    PROGRAM instance0 WITH task0 : PLC2;
  END_RESOURCE
  
END_CONFIGURATION
