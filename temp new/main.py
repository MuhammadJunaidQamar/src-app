# main.py
import csv
import time
import tkinter as tk
from tkinter import ttk, messagebox
import sys
import queue
from serial_port_button import select_com_port
from serial_reader import SerialReader
from main_gui import MissionGUI

BAUD_RATE = 115200
FLAG_WRITE_TO_FILE = 1
UI_POLL_MS = 50   # 20 Hz UI update

def main():
    SERIAL_PORT = select_com_port()

    root = tk.Tk()
    root.title("🛰️ CanSat Mission Control (Stable)")
    root.configure(bg="#070814")
    root.geometry("1280x780")

    # Create a queue where the serial thread will place incoming packets
    data_queue = queue.Queue(maxsize=500)

    # CSV logging setup
    filename = time.strftime("cansat_log_%Y%m%d_%H%M%S.csv")
    logfile = open(filename, "w", newline="")
    writer = csv.DictWriter(logfile, fieldnames=[
        "HardwareTimestamp", "PythonTimestamp",
        "ax","ay","az", "gx","gy","gz",
        "mx","my","mz",
        "temp","press","alt","head",
        "sat","lat","lon","gpsAlt"
    ])
    if FLAG_WRITE_TO_FILE:
        writer.writeheader()
        writer.count = 0

    # --- Create UI (contains tabs and update callbacks) ---
    gui = MissionGUI(root, data_queue)

    # --- Serial callback: only push packet into queue (non-blocking) ---
    def serial_callback(packet):
        try:
            # Put the packet (latest) into queue; if full, drop oldest and add new
            data_queue.put_nowait(packet)
        except queue.Full:
            try:
                # Remove one item then put
                _ = data_queue.get_nowait()
                data_queue.put_nowait(packet)
            except Exception:
                pass

    # --- Start SerialReader thread ---
    reader = SerialReader(port=SERIAL_PORT, baudrate=BAUD_RATE, callback=serial_callback)
    reader.start()

    # --- Close port button behavior (safe) ---
    def close_port():
        nonlocal reader
        try:
            if reader:
                reader.stop()
                # give it a short time to close
                time.sleep(0.1)
                reader = None
            if not logfile.closed:
                logfile.close()
            messagebox.showinfo("Port closed", "Serial port closed and log file saved.")
        except Exception as e:
            messagebox.showerror("Error closing port", str(e))

    # --- Place Close Port button & status bar ---
    bottom = tk.Frame(root, bg="#070814")
    bottom.pack(fill="x", side="bottom", padx=6, pady=6)
    status_var = tk.StringVar(value=f"Port: {SERIAL_PORT} | Running")
    status_lbl = tk.Label(bottom, textvariable=status_var, bg="#070814", fg="#00d4ff")
    status_lbl.pack(side="left", padx=6)
    close_btn = tk.Button(bottom, text="🔌 Close Port", command=close_port,
                          bg="#102036", fg="#FFD36E", relief="flat", padx=10, pady=6)
    close_btn.pack(side="right", padx=8)

    # --- UI poller: run inside Tk main thread at regular interval ---
    def ui_poller():
        """
        Pulls latest packet(s) from the queue (drain) and update GUI once per tick.
        Also writes to CSV here (single threaded) to avoid file contention.
        """
        latest = None
        try:
            # Drain queue: keep only last packet to reduce backlog
            while True:
                latest = data_queue.get_nowait()
        except Exception:
            pass

        if latest is not None:
            # Add Python timestamp using GUI helper
            latest["PythonTimestamp"] = gui.environment.getPythonTimestamp(latest)

            # Update GUI (these methods run quickly; heavy drawing is throttled in GUI code)
            gui.on_new_packet(latest)

            # Logging
            if FLAG_WRITE_TO_FILE:
                try:
                    writer.writerow(latest)
                    writer.count += 1
                    if writer.count % 100 == 0:
                        logfile.flush()
                except Exception as e:
                    print("Logging error:", e)

            # Update status
            status_var.set(f"Port: {SERIAL_PORT} | Last HW TS: {latest.get('HardwareTimestamp','')}")
        # schedule next poll
        root.after(UI_POLL_MS, ui_poller)

    root.after(UI_POLL_MS, ui_poller)

    # --- Window close handler ---
    def on_close():
        # Stop reader and close file
        try:
            if reader:
                reader.stop()
                time.sleep(0.05)
        except Exception:
            pass
        try:
            if not logfile.closed:
                logfile.close()
        except Exception:
            pass
        root.destroy()

    root.protocol("WM_DELETE_WINDOW", on_close)

    try:
        root.mainloop()
    except KeyboardInterrupt:
        pass
    finally:
        on_close()
        sys.exit(0)


if __name__ == "__main__":
    main()
