# -*- coding: utf-8 -*-
import serial
import datetime
import time
import threading
import paho.mqtt.client as mqtt
import json

# ---------- CONFIG ----------

MQTT_HOST = "10.213.69.17"
MQTT_PORT = 1883
TOPIC_CMD = "rk3k/cmd"
TOPIC_COS = "rk3k/cos"

SERIAL_PORT = "COM8"
BAUD = 2400

# Global interval counter and flag
current_interval = 0
pending_flag = False

def compute_interval_from_time(now):
    """Convert current time to 30-second interval index."""
    return now.hour * 120 + now.minute * 2 + (1 if now.second >= 30 else 0)

def initialize_daily_state():
    """Sync interval + flag based on actual system time."""
    global current_interval, pending_flag

    now = datetime.datetime.now()
    current_interval = compute_interval_from_time(now)

    # 1:30 AM = interval 180
    if current_interval <= 180:
        pending_flag = True      # today's *0 event still pending
    else:
        pending_flag = False     # today's event already passed

    print "Daily state initialized: interval =", current_interval, "pending =", pending_flag

def interval_scheduler():
    """Runs every 30 seconds, increments interval, fires *0 at interval 180."""
    global current_interval, pending_flag

    initialize_daily_state()

    while True:

        # Fire at interval 180 if pending
        if current_interval >= 180 and pending_flag:
            print "Firing daily *0 at interval 180"
            mqttc.publish(TOPIC_CMD, "*")
            time.sleep(0.2)
            mqttc.publish(TOPIC_CMD, "0")
            pending_flag = False

        time.sleep(30)

        current_interval += 1

        # Rollover at 2880 → new day
        if current_interval >= 2880:
            initialize_daily_state()

# ---------- SERIAL SETUP ----------

ser = serial.Serial(
    port=SERIAL_PORT,
    baudrate=BAUD,
    bytesize=serial.EIGHTBITS,
    parity=serial.PARITY_NONE,
    stopbits=serial.STOPBITS_ONE,
    timeout=0.1
)

print "Serial open:", ser.isOpen(), "Port:", ser.portstr

# ---------- ENCODER (VB SendChar EQUIVALENT) ----------

def encode_command(ch):
    """
    Encode a single-character RK3K command exactly like the VB SendChar() routine.
    Returns a Python str containing raw bytes.
    """

    # Numeric keys 0-9, *, #
    num_map = {
        "1": (206, "1"),
        "2": (205, "2"),
        "3": (204, "3"),
        "4": (203, "4"),
        "5": (202, "5"),
        "6": (201, "6"),
        "7": (200, "7"),
        "8": (199, "8"),
        "9": (198, "9"),
        "0": (207, "0"),
        "*": (213, "*"),
        "#": (220, "#"),
    }

    # Lowercase f, a, p (keypress)
    lower_special = {
        "f": (185, "F"),
        "a": (190, "A"),
        "p": (175, "P"),
    }

    # Uppercase F, A, P (2-second keypress)
    upper_special = {
        "F": (249, 6),
        "A": (254, 1),
        "P": (239, 16),
    }

    # N, O, R, S, U, V
    ctrl_map = {
        "N": (241, 14),
        "O": (240, 15),
        "R": (237, 18),
        "S": (236, 19),
        "U": (234, 21),
        "V": (233, 22),
    }

    # --- Numeric / *, # ---
    if ch in num_map:
        xor_val, ascii_char = num_map[ch]
        return chr(xor_val) + ascii_char

    # --- Lowercase f, a, p ---
    if ch in lower_special:
        xor_val, upper = lower_special[ch]
        return chr(xor_val) + upper

    # --- Uppercase F, A, P ---
    if ch in upper_special:
        xor_val, ctrl = upper_special[ch]
        return chr(xor_val) + chr(ctrl) + chr(242) + chr(13)

    # --- N, O, R, S, U, V ---
    if ch in ctrl_map:
        xor_val, ctrl = ctrl_map[ch]
        return chr(xor_val) + chr(ctrl)

    # Unknown command → ignore
    return ""

# ---------- MQTT CALLBACKS ----------

def on_connect(client, userdata, flags, rc):
    print "Connected to MQTT with rc =", rc
    client.subscribe(TOPIC_CMD)
    print "Subscribed to", TOPIC_CMD

def on_message(client, userdata, msg):
    #payload = msg.payload  # str in Py2
    #if len(payload) != 1:
    #    # Strict: only single-char commands allowed
    #    print "Ignoring non-single-char payload:", repr(payload)
    #    return

    #out_bytes = encode_command(payload)

    #print "CMD:", repr(payload), "TX:", " ".join("{:02X}".format(ord(c)) for c in out_bytes)

    raw = msg.payload

    # Try JSON first
    try:
        data = json.loads(raw)
        payload = data.get("what", "")
    except:
        # Not JSON → treat as legacy single-char
        payload = raw

    # Enforce single-char command
    if len(payload) != 1:
        #print "Ignoring non-single-char payload:", repr(raw)
        return

    out_bytes = encode_command(payload)

    print "CMD:", repr(payload), "TX:", " ".join("{:02X}".format(ord(c)) for c in out_bytes)
    
    if out_bytes:
        ser.write(out_bytes)

# ---------- SERIAL READER (COS FRAMING + TIMEOUT) ----------

def serial_reader():
    buffer = ""
    last_rx_time = time.time()

    while True:
        data = ser.read(1)

        if data:
            # Timestamp the arrival
            last_rx_time = time.time()

            # Debug raw byte if needed
            # print "RX BYTE:", repr(data)

            # Ignore lone '>' prompt when buffer is empty
            if data == ">" and buffer == "":
                continue

            # CR terminates a COS frame
            if data == "\x0D":
                if buffer:
                    print "COS FRAME:", repr(buffer)
                    mqttc.publish(TOPIC_COS, buffer)
                    buffer = ""
                continue

            # Normal byte → accumulate
            buffer += data

        else:
            # No data this cycle → check timeout
            if buffer and (time.time() - last_rx_time) > 1.0:
                # Timeout: flush partial frame if >1 char
                if len(buffer) > 1:
                    #print "COS TIMEOUT FLUSH:", repr(buffer)
                    mqttc.publish(TOPIC_COS, buffer)
                buffer = ""

        time.sleep(0.005)

# ---------- MQTT SETUP ----------

mqttc = mqtt.Client()
mqttc.on_connect = on_connect
mqttc.on_message = on_message
mqttc.connect(MQTT_HOST, MQTT_PORT, 60)

# ---------- START SERIAL THREAD ----------

t = threading.Thread(target=serial_reader)
t.daemon = True
t.start()

sched = threading.Thread(target=interval_scheduler)
sched.daemon = True
sched.start()

# ---------- MAIN LOOP ----------

#print "RK3K bridge running: MQTT <-> Serial"
mqttc.loop_forever()

