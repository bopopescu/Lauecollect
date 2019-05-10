history_length = 300
stabilization_RMS = 0.01
stabilization_time = 3.0
title = 'Temperature Configuration'
motor_names = ['collect.temperatures', 'collect.temperature_wait', 'collect.temperature_idle', 'collect.temperature_count']
motor_labels = ['list of temperatures', 'wait', 'Idle\ntemp', 'count']
widths = [410, 35, 65, 50]
line0.description = 'NIH:ramp-16_120_0.5_30_20'
line1.description = 'NIH:ramp-16_100_0.5_30_20'
line0.collect.temperatures = 'ramp(low=-16,high=60,step=0.5,hold_low=30,hold_high=20)'
line1.collect.temperatures = 'ramp(low=-16,high=100.,step=0.5,hold_low=30,hold_high=20)'
line1.updated = '2019-03-21 12:52:55'
row_height = 40
line0.updated = '2019-05-09 21:46:28'
description_width = 130
nrows = 17
line2.description = 'NIH:NCBD'
line2.updated = '2019-03-24 23:33:04'
line2.collect.temperatures = '11.0, 13.5, 35.5'
names = ['list', 'wait', 'idle', 'count']
line0.collect.temperature_wait = 0
line1.collect.temperature_wait = '0'
line2.collect.temperature_wait = '1'
line0.collect.temperature_idle = 22.0
line1.collect.temperature_idle = '22.0'
line2.collect.temperature_idle = '22.0'
command_row = 5
formats = ['%s', '%g', '%g', '%g']
line3.description = 'NIH:NCBD_Tjump'
line3.collect.temperatures = '-16,11, 35'
line3.updated = '2019-03-25 00:49:27'
line3.collect.temperature_wait = 1.0
line3.collect.temperature_idle = 22.0
line0.collect.temperature_count = nan
line4.description = 'NIH:ramp-16_80_0.5_30_20'
line4.collect.temperatures = 'ramp(low=-16,high=80,step=0.5,hold_low=30,hold_high=20)'
line4.collect.temperature_wait = 0
line4.collect.temperature_idle = 22.0
line4.updated = '2019-03-21 15:43:15'
line4.collect.temperature_count = nan
line5.description = 'None'
line5.collect.temperatures = ''
line5.collect.temperature_wait = nan
line5.collect.temperature_idle = nan
line5.updated = '2019-03-20 09:00:11'
line6.description = 'NIH:static-discrete-temp'
line6.collect.temperatures = '-16, 0, 20,  40, 60, 80, 100.0, 120'
line6.collect.temperature_wait = 1.0
line6.collect.temperature_idle = 22.0
line6.updated = '2019-02-03 02:22:51'
line7.collect.temperatures = '15, 22, 29, 36, 43'
line7.collect.temperature_wait = 1
line7.collect.temperature_idle = 22.0
line7.collect.temperature_count = nan
line7.updated = '29 Oct 02:23'
line7.description = 'NIH:Thompson'
command_rows = [0]
line8.description = 'NIH:Thompson:T-Jump'
line8.collect.temperatures = '18'
line8.collect.temperature_idle = 18.0
line8.collect.temperature_wait = 1.0
line8.updated = '03 Nov 19:13'
line9.description = 'NIH:Overlap'
line9.collect.temperatures = '22, 25, 47'
line9.collect.temperature_idle = 22.0
line9.collect.temperature_wait = 1.0
line9.collect.temperature_count = nan
line9.updated = '2019-03-21 00:49:19'
line1.collect.temperature_count = nan
line10.description = 'NIH:Water'
line10.collect.temperatures = '19.5, 22, 44'
line10.updated = '2019-03-24 09:17:51'
line10.collect.temperature_wait = 1.0
line10.collect.temperature_idle = 22.0
line11.description = 'NIH:GB3-static'
line12.description = 'NIH:GB3-T-jump'
line11.collect.temperatures = '-12.7, 9, 38.3, 60, 70.3, 81.7, 92, 113.7'
line11.updated = '2019-02-01 18:36:28'
line12.collect.temperatures = '-16, 35, 56.7, 67, 88.7'
line12.updated = '2019-02-01 18:36:38'
line11.collect.temperature_wait = 1.0
line11.collect.temperature_idle = 22.0
line12.collect.temperature_idle = 22.0
line12.collect.temperature_wait = 1.0
line14.collect.temperatures = '56.5, 75.5, 88.5, 93.5'
line14.updated = '2019-03-23 16:20:21'
line14.collect.temperature_wait = 1
line14.collect.temperature_idle = 22.0
line14.collect.temperature_count = nan
line13.collect.temperatures = '-13.5, 8.5, 30.5, 46.5, 68.5'
line13.updated = '2019-03-21 02:14:56'
line13.collect.temperature_wait = 1
line13.collect.temperature_idle = 22.0
line13.collect.temperature_count = nan
line13.description = 'NIH:HAG-static'
line14.description = 'NIH:RNA-T-jump-HT'
line15.collect.temperatures = '-16.0, 19.5, 56.5, 75.5, 88.5'
line15.updated = '2019-03-23 21:21:01'
line15.collect.temperature_wait = 1
line15.collect.temperature_idle = 22.0
line15.collect.temperature_count = nan
line15.description = 'NIH:RNA-T-jump'
line16.description = 'Temp_95.5C'
line16.collect.temperatures = '95.5'
line16.updated = '2019-03-25 05:27:04'
line16.collect.temperature_idle = 22.0
line16.collect.temperature_wait = 1.0