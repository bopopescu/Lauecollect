SN = '57D81C13'
scan_lst = ['0', '1', '2', '3']
phys_ch_lst = ['0', '1', '2', '3']
gain_lst = ['5', '5', '5', 'T-thrmc']
RingBuffer_size = 4320000
time_out = 0.1
cjc_value = -2.0
calib = [0.5607564290364583, 2.704498291015625, 2.660015869140625, -3.2, 1553209216.642]
socket = ['164.54.161.34', 2030]
type_def = '\x8b\x00\xa80:init()\x01\xa91:close()\x02\xda\x00,2:broadcast fixed rate(in: float, out: None)\x03\xda\x00(3:request average of N (in:N, out:float)\x04\xda\x00,4:request buffer all(in: None, out: nparray)\x05\xda\x0005:request buffer update(in:pointer, out:nparray)\x06\xda\x00-6:perform calibration(in: None, out: nparray)\x07\xda\x00)7:get calibration(in: None, out: nparray)\x08\xda\x00%8:save to a file(in: None, out: none)\xfe\xda\x00 -2:dev_info(in: None, out: dict)\xff\xbf-1:type_def(in:None, out: dict)'