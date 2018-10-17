
ble-bind --csi '1~' home
ble-bind --csi '2~' insert
ble-bind --csi '3~' delete
ble-bind --csi '4~' end
ble-bind --csi '5~' prior
ble-bind --csi '6~' next

ble-bind --csi 'A' up
ble-bind --csi 'B' down
ble-bind --csi 'C' right
ble-bind --csi 'D' left
ble-bind -k 'ESC O A' up
ble-bind -k 'ESC O B' down
ble-bind -k 'ESC O C' right
ble-bind -k 'ESC O D' left

# screen
ble-bind --csi 'P' f1
ble-bind --csi 'Q' f2
ble-bind --csi 'R' f3
ble-bind --csi 'S' f4
ble-bind -k 'ESC O P' f1
ble-bind -k 'ESC O Q' f2
ble-bind -k 'ESC O R' f3
ble-bind -k 'ESC O S' f4

# rosaterm
ble-bind --csi '11~' f1
ble-bind --csi '12~' f2
ble-bind --csi '13~' f3
ble-bind --csi '14~' f4

# cygwin
ble-bind -k 'ESC [ [ A' f1
ble-bind -k 'ESC [ [ B' f2
ble-bind -k 'ESC [ [ C' f3
ble-bind -k 'ESC [ [ D' f4
