This esp32 uses an MQTT broker to talk to a PIC 16C84 that is connected to a PC with a PYTHON script linked to the MQTT broker AND connected directly to the
4 wire Keyboard bus of the DSC PC3000 ... DSC PC1500 also works with this keypad it will only display 8 zones though ... the DSC MAX has a similar 4 wire 
keypad bus but a different interface would be required with more display details ... included in this git is also the pic asm/h files ... the pic python to mqtt
required get esp32-core ... AND a mqtt broker will be require to tie the pic/python and esp32 together
