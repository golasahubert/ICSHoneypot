TYPE=VIEW
query=select `scadalts`.`plcAlarms`.`id` AS `id`,`func_fromats_date`(`scadalts`.`plcAlarms`.`activeTime`) AS `activation-time`,`func_fromats_date`(`scadalts`.`plcAlarms`.`inactiveTime`) AS `inactivation-time`,`scadalts`.`plcAlarms`.`dataPointType` AS `level`,`scadalts`.`plcAlarms`.`dataPointName` AS `name`,`scadalts`.`plcAlarms`.`dataPointId` AS `dataPointId` from `scadalts`.`plcAlarms` where ((`scadalts`.`plcAlarms`.`acknowledgeTime` = 0) and ((`scadalts`.`plcAlarms`.`inactiveTime` = 0) or (`scadalts`.`plcAlarms`.`inactiveTime` > (unix_timestamp((now() - interval 24 hour)) * 1000)))) order by (`scadalts`.`plcAlarms`.`inactiveTime` = 0) desc,`scadalts`.`plcAlarms`.`activeTime` desc,`scadalts`.`plcAlarms`.`inactiveTime` desc,`scadalts`.`plcAlarms`.`id` desc
md5=187deb070bb86e856d9031cebd880870
updatable=1
algorithm=0
definer_user=root
definer_host=%
suid=2
with_check_option=0
timestamp=2026-01-19 09:39:39
create-version=1
source=SELECT  id,  func_fromats_date(activeTime) AS \'activation-time\',  func_fromats_date(inactiveTime) AS \'inactivation-time\',  dataPointType AS \'level\',  dataPointName AS \'name\',  dataPointId AS dataPointId FROM plcAlarms WHERE acknowledgeTime = 0   AND (inactiveTime = 0 OR (inactiveTime > UNIX_TIMESTAMP(NOW() - INTERVAL 24 HOUR) * 1000)) ORDER BY inactiveTime = 0 DESC, activeTime DESC, inactiveTime DESC, id DESC
client_cs_name=utf8mb4
connection_cl_name=utf8mb4_general_ci
view_body_utf8=select `scadalts`.`plcAlarms`.`id` AS `id`,`func_fromats_date`(`scadalts`.`plcAlarms`.`activeTime`) AS `activation-time`,`func_fromats_date`(`scadalts`.`plcAlarms`.`inactiveTime`) AS `inactivation-time`,`scadalts`.`plcAlarms`.`dataPointType` AS `level`,`scadalts`.`plcAlarms`.`dataPointName` AS `name`,`scadalts`.`plcAlarms`.`dataPointId` AS `dataPointId` from `scadalts`.`plcAlarms` where ((`scadalts`.`plcAlarms`.`acknowledgeTime` = 0) and ((`scadalts`.`plcAlarms`.`inactiveTime` = 0) or (`scadalts`.`plcAlarms`.`inactiveTime` > (unix_timestamp((now() - interval 24 hour)) * 1000)))) order by (`scadalts`.`plcAlarms`.`inactiveTime` = 0) desc,`scadalts`.`plcAlarms`.`activeTime` desc,`scadalts`.`plcAlarms`.`inactiveTime` desc,`scadalts`.`plcAlarms`.`id` desc
