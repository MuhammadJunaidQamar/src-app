import asyncio
import csv
import json
import logging
import os
import threading
import time
import tkinter as tk
from typing import Any, Dict, Optional, Union

from  serial_port_button import select_com_port
from   serial_reader import SerialReader
import sys
from sensor_gui import CanSatGUI
from gyro_gui   import GyroGUI

try:
    import websockets  # type: ignore
except ImportError:  # pragma: no cover - optional dependency
    websockets = None

BAUD_RATE = 115200
FLAG_WRITE_TO_FILE = 1
POLL_PERIOD  =      1
DEFAULT_WEBSOCKET_URL = os.environ.get("CANSAT_WS_URL", "ws://localhost:8765/telemetry").strip()
if DEFAULT_WEBSOCKET_URL == "":
    DEFAULT_WEBSOCKET_URL = None

try:
    DEFAULT_RECONNECT_SECONDS = float(os.environ.get("CANSAT_WS_RECONNECT", "5"))
except ValueError:
    DEFAULT_RECONNECT_SECONDS = 5.0


class WebSocketPublisher:
    """Background WebSocket publisher with automatic reconnect."""

    def __init__(self, uri: str, reconnect_delay: float = 5.0) -> None:
        if not uri:
            raise ValueError("A non-empty WebSocket URI is required")
        if websockets is None:
            raise RuntimeError(
                "websockets package is not installed. Install with 'pip install websockets'."
            )

        self.uri = uri
        self.reconnect_delay = max(reconnect_delay, 1.0)
        self._loop = asyncio.new_event_loop()
        self._loop_ready = threading.Event()
        self._stop_event = threading.Event()
        self._queue: Optional[asyncio.Queue[Optional[str]]] = None
        self._thread = threading.Thread(target=self._run_loop, daemon=True)
        self._logger = logging.getLogger("cansat.websocket.publisher")
        self._thread.start()
        self._loop_ready.wait()

    def _run_loop(self) -> None:
        asyncio.set_event_loop(self._loop)
        self._queue = asyncio.Queue()
        self._loop.create_task(self._publisher())
        self._loop_ready.set()
        try:
            self._loop.run_forever()
        finally:
            pending = asyncio.all_tasks(self._loop)
            for task in pending:
                task.cancel()
            if pending:
                self._loop.run_until_complete(asyncio.gather(*pending, return_exceptions=True))
            self._loop.close()

    async def _publisher(self) -> None:
        assert self._queue is not None
        pending_message: Optional[str] = None

        while not self._stop_event.is_set():
            try:
                async with websockets.connect(self.uri, ping_interval=20, ping_timeout=20) as websocket:
                    self._logger.info("Connected to %s", self.uri)
                    while not self._stop_event.is_set():
                        if pending_message is None:
                            pending_message = await self._queue.get()
                        if pending_message is None:  # shutdown sentinel
                            await websocket.close()
                            return

                        await websocket.send(pending_message)
                        pending_message = None

            except asyncio.CancelledError:
                raise
            except Exception as exc:  # noqa: BLE001 - want to catch everything to keep retrying
                self._logger.warning("WebSocket connection error: %s", exc)
                if pending_message is not None:
                    await self._queue.put(pending_message)
                    pending_message = None
                await asyncio.sleep(self.reconnect_delay)

        # Drain any remaining sentinel to allow graceful shutdown
        while not self._queue.empty():
            item = await self._queue.get()
            if item is None:
                break

    def send(self, payload: Union[str, Dict[str, Any]]) -> None:
        """Queue a payload (dict or JSON string) to be sent."""
        if self._stop_event.is_set() or not self._loop_ready.is_set():
            return

        message: str
        if isinstance(payload, str):
            message = payload
        else:
            message = json.dumps(payload, ensure_ascii=False)

        assert self._queue is not None
        asyncio.run_coroutine_threadsafe(self._queue.put(message), self._loop)

    def close(self) -> None:
        if self._stop_event.is_set():
            return

        self._stop_event.set()
        if self._loop_ready.is_set() and self._queue is not None:
            asyncio.run_coroutine_threadsafe(self._queue.put(None), self._loop)
        self._loop.call_soon_threadsafe(self._loop.stop)
        self._thread.join(timeout=5)

def main():
    SERIAL_PORT = select_com_port()    # adjust to your COM port

    websocket_url = DEFAULT_WEBSOCKET_URL
    ws_publisher: Optional[WebSocketPublisher] = None
    if websocket_url:
        try:
            ws_publisher = WebSocketPublisher(websocket_url, DEFAULT_RECONNECT_SECONDS)
            print(f"WebSocket publishing enabled: {websocket_url}")
        except Exception as exc:  # noqa: BLE001 - report and continue without websocket
            print(f"Warning: WebSocket publishing disabled ({exc})")
            ws_publisher = None
    else:
        print("WebSocket publishing disabled. Set CANSAT_WS_URL to enable streaming.")

    # --- Tkinter root GUI setup for CanSat and Gyro ---
    root = tk.Tk()
    root.title("CanSat Monitor")
    canSat_monitor = CanSatGUI(root)

    # --- Separate window for Gyro GUI ---
    gyro_window = tk.Toplevel(root)
    gyro_window.title("Gyro Monitor")
    gyro_monitor = GyroGUI(gyro_window)

    # --- Setup CSV log file ---
    filename = time.strftime("cansat_log_%Y%m%d_%H%M%S.csv")
    logfile = open(filename, "w", newline="")
    writer = csv.DictWriter(
        logfile,
        fieldnames=[
            "HardwareTimestamp", "PythonTimestamp",
            "ax","ay","az", "gx","gy","gz",
            "mx","my","mz",
            "temp","press","alt","head",
            "sat","lat","lon","gpsAlt"
        ]
    )
    writer.count = 0
    if FLAG_WRITE_TO_FILE:
        writer.writeheader()

    # --- Packet callback ---
    def cansat_packet_callback(data):
        """Called from SerialReader thread when a packet arrives."""
        try:
            data["PythonTimestamp"] = canSat_monitor.getPythonTimestamp(data)
            
            # 1) Update GUI (schedule on Tkinter thread)
            if not hasattr(cansat_packet_callback, "last_update"):
                cansat_packet_callback.last_update = 0 

            canSat_monitor.update_state(data) 
            gyro_monitor.update_state( [data[key] for key in ["gx", "gy", "gz"]], data["HardwareTimestamp"] )   
            now = time.time()
            if now - cansat_packet_callback.last_update >= 0.05:  # ~20 Hz update
                cansat_packet_callback.last_update = now
                try:
                    root.after(0, lambda d=data.copy(): canSat_monitor.update_fields(d))
                    root.after(0, lambda d=data.copy(): gyro_monitor.update_gyro( 
                        [d[key] for key in ["gx", "gy", "gz"]], d["HardwareTimestamp"] ))
                except tk.TclError:
                    # Window was closed
                    pass
            
            # 2) Write to CSV
            if FLAG_WRITE_TO_FILE and not logfile.closed:
                try:
                    writer.writerow(data)
                    writer.count += 1
                    if writer.count % 100 == 0:   # flush every 100 packets
                        logfile.flush()
                except (ValueError, OSError) as e:
                    print(f"CSV write error: {e}")
            
            if ws_publisher:
                try:
                    ws_publisher.send(data)
                except Exception as e:
                    print(f"WebSocket send error: {e}")

            # Print for debugging
            try:
                print(
                    f"T: {data['temp']:.2f} °C | "
                    f"Alt: {data['alt']:.2f} m | "
                    f"Acc: ({data['ax']:.2f}, {data['ay']:.2f}, {data['az']:.2f}) | "
                    f"Gyro: ({data['gx']:.2f}, {data['gy']:.2f}, {data['gz']:.2f}) | "
                    f"Head: {data['head']:.2f}° | "
                    f"Sat: {data['sat']} | "
                    f"TS: {data['HardwareTimestamp']}",
                    end="\r",
                    flush=True
                )
            except (KeyError, ValueError):
                pass
        except Exception as e:
            print(f"Error in packet callback: {e}")


    # --- Close handler ---
    def on_close():
        print("\nShutting down...")
        try:
            print("Stopping serial reader...")
            reader.stop()
        except Exception as e:
            print(f"Error stopping serial reader: {e}")
        
        try:
            print("Closing log file...")
            if not logfile.closed:
                logfile.flush()
                logfile.close()
        except Exception as e:
            print(f"Error closing log file: {e}")

        try:
            if ws_publisher:
                print("Closing WebSocket...")
                ws_publisher.close()
        except Exception as e:
            print(f"Error closing WebSocket: {e}")
        
        try:
            root.destroy()
        except Exception as e:
            print(f"Error destroying window: {e}")

    root.protocol("WM_DELETE_WINDOW", on_close)

    # --- Serial reader ---
    reader = SerialReader(port=SERIAL_PORT, baudrate=115200, callback=cansat_packet_callback)
    reader.start()

    # --- Tkinter loop keeps program alive ---
    try:
        root.mainloop()
    except KeyboardInterrupt:
        print("\nInterrupted with Ctrl-C!")
    except Exception as e:
        print(f"\nUnexpected error in main loop: {e}")
    finally:
        print("\nCleaning up...")
        try:
            reader.stop()
        except:
            pass
        try:
            if not logfile.closed:
                logfile.flush()
                logfile.close()
        except:
            pass
        try:
            if ws_publisher:
                ws_publisher.close()
        except:
            pass
        print("Shutdown complete.")
        sys.exit(0)



def __init__(self, root):
    self.T0 = time.time()
    self.count = 0

if __name__ == "__main__":
    main()


