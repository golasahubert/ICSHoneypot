TYPE=VIEW
query=select `func_fromats_date`(`scadalts`.`plcAlarms`.`activeTime`) AS `activeTime`,`func_fromats_date`(`scadalts`.`plcAlarms`.`inactiveTime`) AS `inactiveTime`,`func_fromats_date`(`scadalts`.`plcAlarms`.`acknowledgeTime`) AS `acknowledgeTime`,`scadalts`.`plcAlarms`.`level` AS `level`,`scadalts`.`plcAlarms`.`dataPointName` AS `name` from `scadalts`.`plcAlarms` order by (`scadalts`.`plcAlarms`.`inactiveTime` = 0) desc,`func_fromats_date`(`scadalts`.`plcAlarms`.`inactiveTime`) desc,`scadalts`.`plcAlarms`.`id` desc
md5=8eb9d0603750b80cdf28810fb3e35045
updatable=1
algorithm=0
definer_user=root
definer_host=%
suid=2
with_check_option=0
timestamp=2026-01-19 09:39:39
create-version=1
source=SELECT func_fromats_date(activeTime) AS \'activeTime\',\nfunc_fromats_date(inactiveTime) AS \'inactiveTime\',\nfunc_fromats_date(acknowledgeTime) AS \'acknowledgeTime\',\nlevel,\ndataPointName AS \'name\' \nFROM plcAlarms ORDER BY inactiveTime = 0 DESC, inactiveTime DESC, id DESC
client_cs_name=utf8mb4
connection_cl_name=utf8mb4_general_ci
view_body_utf8=select `func_fromats_date`(`scadalts`.`plcAlarms`.`activeTime`) AS `activeTime`,`func_fromats_date`(`scadalts`.`plcAlarms`.`inactiveTime`) AS `inactiveTime`,`func_fromats_date`(`scadalts`.`plcAlarms`.`acknowledgeTime`) AS `acknowledgeTime`,`scadalts`.`plcAlarms`.`level` AS `level`,`scadalts`.`plcAlarms`.`dataPointName` AS `name` from `scadalts`.`plcAlarms` order by (`scadalts`.`plcAlarms`.`inactiveTime` = 0) desc,`func_fromats_date`(`scadalts`.`plcAlarms`.`inactiveTime`) desc,`scadalts`.`plcAlarms`.`id` desc
