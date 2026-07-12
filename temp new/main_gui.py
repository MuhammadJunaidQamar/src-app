# main_gui.py
import tkinter as tk
from tkinter import ttk
import time
import numpy as np
import matplotlib
matplotlib.use("TkAgg")
import matplotlib.pyplot as plt
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from collections import deque
from tkintermapview import TkinterMapView
from mpl_toolkits.mplot3d import Axes3D  # noqa

# ---------------- theme & throttles ----------------
BG = "#070814"
BOX_BG = "#0b1220"
ACCENT = "#00d4ff"
GOLD = "#FFD36E"
TEXT = "#dbeafe"

MAP_UPDATE_MIN_S = 0.8
GYRO_DRAW_MIN_MS = 50  # Reduced delay for faster updates
GAUGE_DPI = 110

# ---------------- Mission GUI ----------------
class MissionGUI:
    def __init__(self, root, data_queue):
        self.root = root
        self.data_queue = data_queue

        style = ttk.Style(root)
        style.theme_use("clam")
        style.configure("TNotebook", background=BG, borderwidth=0)
        style.configure("TNotebook.Tab", background="#0d1524", foreground=TEXT, padding=[10, 6])
        style.map("TNotebook.Tab", background=[("selected", "#1d2b45")])

        nb = ttk.Notebook(root)
        nb.pack(fill="both", expand=True, padx=8, pady=8)

        frame_env = tk.Frame(nb, bg=BG)
        frame_gps = tk.Frame(nb, bg=BG)
        frame_gyro = tk.Frame(nb, bg=BG)

        nb.add(frame_env, text="Environment")
        nb.add(frame_gps, text="GPS")
        nb.add(frame_gyro, text="Gyro (3D)")

        self.environment = TabEnvironment(frame_env)
        self.gps = TabGPS(frame_gps)
        self.gyro = TabGyro3D(frame_gyro)

    def on_new_packet(self, packet):
        try:
            self.environment.update_fields(packet)
        except Exception as e:
            print("Env update error:", e)
        try:
            self.gps.update_fields(packet)
        except Exception as e:
            print("GPS update error:", e)
        try:
            # Fix: Ensure gyro values are properly passed
            gx = packet.get("gx", 0)
            gy = packet.get("gy", 0) 
            gz = packet.get("gz", 0)
            timestamp = packet.get("HardwareTimestamp", time.time() * 1000)
            self.gyro.update_state([gx, gy, gz], timestamp)
            self.gyro.request_draw()
        except Exception as e:
            print("Gyro update error:", e)

# ---------------- Environment Tab (Updated to match image) ----------------
class TabEnvironment:
    def __init__(self, parent):
        self.root = parent
        self.root.configure(bg=BG)
        self.buf_len = 200
        self.buffers = {
            k: deque([0.0]*self.buf_len, maxlen=self.buf_len)
            for k in ("temp", "press", "alt", "head", "ax", "ay", "az", "mx", "my", "mz")
        }

        # Main title
        tk.Label(self.root, text="Environment Sensors", font=("Inter", 18, "bold"), 
                fg=ACCENT, bg=BG).pack(pady=8)

        # Create two columns for the dashboard
        main_frame = tk.Frame(self.root, bg=BG)
        main_frame.pack(fill="both", expand=True, padx=10, pady=10)

        # Left column
        left_frame = tk.Frame(main_frame, bg=BG)
        left_frame.pack(side="left", fill="both", expand=True, padx=5)

        # Right column
        right_frame = tk.Frame(main_frame, bg=BG)
        right_frame.pack(side="right", fill="both", expand=True, padx=5)

        # Define all sensors with their ranges and units
        sensors = [
            # Left column
            {"key": "temp", "name": "Temperature", "unit": "°C", "range": [-10, 60], "color": "#FF6B6B"},
            {"key": "alt", "name": "Altitude", "unit": "m", "range": [-50, 100], "color": "#4ECDC4"},
            {"key": "press", "name": "Atmospheric Pressure", "unit": "Pa", "range": [0, 110000], "color": "#45B7D1"},
            {"key": "head", "name": "Orientation (Dyno)", "unit": "°", "range": [-15000, 25000], "color": "#96CEB4"},
            
            # Right column  
            {"key": "ax", "name": "Acceleration", "unit": "m/s²", "range": [-15000, 25000], "color": "#FECA57"},
            {"key": "ay", "name": "UV Radiation", "unit": "UV", "range": [0, 15], "color": "#FF9FF3"},
            {"key": "az", "name": "Magnetic Field", "unit": "μT", "range": [-1000, 250000], "color": "#54A0FF"},
            {"key": "mx", "name": "Humidity", "unit": "%", "range": [0, 100], "color": "#5F27CD"},
        ]

        self.cards = {}
        
        # Create sensor cards in two columns
        for i, sensor in enumerate(sensors):
            if i < 4:
                parent_frame = left_frame
            else:
                parent_frame = right_frame
            
            card = self._create_sensor_card(parent_frame, sensor)
            self.cards[sensor["key"]] = card

    def _create_sensor_card(self, parent, sensor):
        card_frame = tk.Frame(parent, bg=BOX_BG, relief="ridge", bd=1, padx=10, pady=8)
        card_frame.pack(fill="x", pady=6, padx=5)

        # Header with sensor name
        header_frame = tk.Frame(card_frame, bg=BOX_BG)
        header_frame.pack(fill="x")
        
        tk.Label(header_frame, text=sensor["name"], font=("Inter", 12, "bold"), 
                fg=GOLD, bg=BOX_BG).pack(side="left")
        
        # Current value display
        value_var = tk.StringVar(value="0.00")
        value_label = tk.Label(header_frame, textvariable=value_var, font=("Inter", 14, "bold"),
                              fg=TEXT, bg=BOX_BG)
        value_label.pack(side="right")
        
        # Create the plot
        fig, ax = plt.subplots(figsize=(4, 1.2), dpi=80)
        ax.set_facecolor(BOX_BG)
        fig.patch.set_facecolor(BOX_BG)
        
        # Set y-axis range based on sensor
        ax.set_ylim(sensor["range"][0], sensor["range"][1])
        ax.set_xlim(0, self.buf_len)
        
        # Remove borders and ticks for clean look
        ax.spines['top'].set_visible(False)
        ax.spines['right'].set_visible(False)
        ax.spines['bottom'].set_visible(False)
        ax.spines['left'].set_visible(False)
        ax.tick_params(colors=TEXT, labelsize=8)
        ax.set_ylabel(sensor["unit"], color=TEXT, fontsize=9)
        
        # Create the plot line
        line, = ax.plot(range(self.buf_len), self.buffers[sensor["key"]], 
                       color=sensor["color"], linewidth=1.5)
        
        # Add to canvas
        canvas = FigureCanvasTkAgg(fig, master=card_frame)
        canvas.draw()
        canvas.get_tk_widget().pack(fill="x", pady=(5, 0))
        
        return {
            "val": value_var,
            "line": line,
            "ax": ax,
            "canvas": canvas,
            "range": sensor["range"]
        }

    def getPythonTimestamp(self, data):
        return int(time.time() * 1000)

    def update_fields(self, data):
        for key, card in self.cards.items():
            try:
                val = float(data.get(key, 0))
            except Exception:
                val = 0.0
            
            self.buffers[key].append(val)
            card["val"].set(f"{val:.2f}")
            
            line = card["line"]
            line.set_ydata(self.buffers[key])
            
            # Auto-scale y-axis within sensor range
            arr = np.array(self.buffers[key])
            if len(arr) > 0:
                y_min = max(card["range"][0], arr.min() - 1)
                y_max = min(card["range"][1], arr.max() + 1)
                card["ax"].set_ylim(y_min, y_max)
            
            card["canvas"].draw_idle()

# ---------------- GPS Tab (Fixed) ----------------
class TabGPS:
    def __init__(self, parent):
        self.root = parent
        self.root.configure(bg=BG)
        self.lock_updates = False
        self._last_map_update = 0.0
        self.marker = None

        tk.Label(self.root, text="GPS Tracker — Map View", font=("Inter", 18, "bold"), 
                fg=ACCENT, bg=BG).pack(pady=8)
        
        info = tk.Frame(self.root, bg=BG)
        info.pack(fill="x", padx=12)
        
        self.vars = {k: tk.StringVar(value="0") for k in ("sat", "lat", "lon", "gpsAlt")}
        self.entries = {}
        
        labels = [("sat", "Satellites"), ("lat", "Latitude"), ("lon", "Longitude"), ("gpsAlt", "GPS Alt (m)")]
        for i, (k, txt) in enumerate(labels):
            tk.Label(info, text=txt + ":", fg=GOLD, bg=BG, font=("Inter", 11, "bold")).grid(
                row=i, column=0, sticky="w", padx=8, pady=4)
            ent = tk.Entry(info, textvariable=self.vars[k], bg=BOX_BG, fg=TEXT, 
                          relief="flat", width=18, state="readonly")
            ent.grid(row=i, column=1, sticky="w", padx=8, pady=4)
            self.entries[k] = ent

        # Control buttons
        btnf = tk.Frame(info, bg=BG)
        btnf.grid(row=0, column=2, rowspan=2, padx=8)
        
        self.lock_btn = tk.Button(btnf, text="🔒 No More Updates: OFF", command=self.toggle_lock,
                                 bg="#102036", fg=GOLD, relief="flat", padx=8, pady=6)
        self.lock_btn.pack(fill="x", pady=4)
        
        self.apply_btn = tk.Button(btnf, text="📍 Upload My Own Lat/Lon", command=self.apply_manual,
                                  bg="#102036", fg=GOLD, relief="flat", padx=8, pady=6)
        self.apply_btn.pack(fill="x", pady=4)

        # Map widget
        self.map_widget = TkinterMapView(self.root, width=900, height=520, corner_radius=8)
        self.map_widget.pack(padx=12, pady=8)
        self.map_widget.set_tile_server(
            "https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token=pk.eyJ1IjoidW5pdmVyc2l0eS1vZi1jZW50cmFsLXB1bmphYiIsImEiOiJjbWhkYjIxaXIwMTJ2MmxzZmFjdmJucGRiIn0.vm5H9G2th-w2CsKvnqpXtw"
        )
        
        # Set initial position
        self.map_widget.set_position(28.6139, 77.2090)  # Default to Delhi
        self.map_widget.set_zoom(10)

    def toggle_lock(self):
        self.lock_updates = not self.lock_updates
        state_text = "OFF" if not self.lock_updates else "ON"
        self.lock_btn.config(text=f"🔒 No More Updates: {state_text}")
        
        # Make lat/lon/gpsAlt editable when locked
        state = "normal" if self.lock_updates else "readonly"
        bg_color = BOX_BG if self.lock_updates else BOX_BG
        for k in ("lat", "lon", "gpsAlt"):
            self.entries[k].config(state=state, bg=bg_color)

    def apply_manual(self):
        try:
            lat = float(self.vars["lat"].get())
            lon = float(self.vars["lon"].get())
        except Exception:
            print("Invalid manual coordinates")
            return
        
        # Update map position and marker
        self.map_widget.set_position(lat, lon)
        self.map_widget.set_zoom(15)  # Zoom in on manual location
        self._set_marker(lat, lon, force=True)
        print(f"Manual coordinates applied: {lat:.6f}, {lon:.6f}")

    def _set_marker(self, lat, lon, force=False):
        now = time.time()
        if (now - self._last_map_update) < MAP_UPDATE_MIN_S and not force:
            return
        self._last_map_update = now
        
        try:
            if self.marker is None:
                self.marker = self.map_widget.set_marker(lat, lon, text="CanSat")
            else:
                self.marker.set_position(lat, lon)
        except Exception as e:
            print("Map marker error:", e)

    def update_fields(self, data):
        # If locked, don't update from sensor data
        if self.lock_updates:
            return
            
        try:
            lat_raw = data.get("lat", None)
            lon_raw = data.get("lon", None)
            lat = float(lat_raw) if lat_raw is not None else None
            lon = float(lon_raw) if lon_raw is not None else None
        except Exception:
            return
            
        if lat is None or lon is None or (lat == 0.0 and lon == 0.0):
            return
            
        # Update display fields
        self.vars["lat"].set(f"{lat:.6f}")
        self.vars["lon"].set(f"{lon:.6f}")  # Fixed: was using lat for lon
        self.vars["sat"].set(str(data.get("sat", "")))
        self.vars["gpsAlt"].set(str(data.get("gpsAlt", "")))
        
        # Update map
        self._set_marker(lat, lon, force=False)

# ---------------- Gyro Tab (3D Cylinder + Needle Dials) ----------------
class TabGyro3D:
    def __init__(self, parent):
        self.root = parent
        self.root.configure(bg=BG)

        # Header
        header = tk.Frame(self.root, bg=BG)
        header.pack(fill="x", pady=(8, 6))
        
        tk.Label(header, text="Gyroscope — 3D Orientation", font=("Inter", 18, "bold"), 
                fg=ACCENT, bg=BG).pack(side="left", padx=12)
        
        tk.Button(header, text="🔄 Reset Orientation", command=self.reset_orientation,
                 bg="#102036", fg=GOLD, relief="flat", padx=8, pady=6).pack(side="right", padx=10)

        # Stats display
        stats = tk.Frame(self.root, bg=BG)
        stats.pack(side="top", fill="x", padx=12, pady=6)
        
        self.gvars = {k: tk.StringVar(value="0.00") for k in ("gx", "gy", "gz", "ax", "ay", "az")}
        labels = [
            ("gx", "Gx (°/s)"), ("gy", "Gy (°/s)"), ("gz", "Gz (°/s)"),
            ("ax", "Angle X (°)"), ("ay", "Angle Y (°)"), ("az", "Angle Z (°)")
        ]
        
        for i, (k, lab) in enumerate(labels):
            tk.Label(stats, text=lab, fg=GOLD, bg=BG, font=("Inter", 11, "bold")).grid(
                row=i // 3, column=(i % 3) * 2, sticky="w", padx=6, pady=3)
            tk.Label(stats, textvariable=self.gvars[k], fg=TEXT, bg=BG, font=("Inter", 12)).grid(
                row=i // 3, column=(i % 3) * 2 + 1, sticky="w", padx=6, pady=3)

        # Main content frame for 3D and dials
        main_content = tk.Frame(self.root, bg=BG)
        main_content.pack(fill="both", expand=True, padx=12, pady=6)

        # Left side - 3D Visualization
        left_frame = tk.Frame(main_content, bg=BG)
        left_frame.pack(side="left", fill="both", expand=True, padx=(0, 10))

        self.fig = plt.figure(figsize=(6, 5), facecolor=BOX_BG)
        self.ax3d = self.fig.add_subplot(111, projection='3d', facecolor=BOX_BG)
        
        self.canvas = FigureCanvasTkAgg(self.fig, master=left_frame)
        self.canvas.get_tk_widget().pack(fill="both", expand=True)

        # Right side - Needle Dials
        right_frame = tk.Frame(main_content, bg=BG)
        right_frame.pack(side="right", fill="both", padx=(10, 0))

        # Create three beautiful dials
        self.dials = []
        self._make_dial(right_frame, "Angle X", 0)
        self._make_dial(right_frame, "Angle Y", 1)
        self._make_dial(right_frame, "Angle Z", 2)

        # Create beautiful cylinder
        self._create_cylinder()
        self._draw_static_frame()

        # Gyro internals
        self.anglex = self.angley = self.anglez = 0.0
        self.bias_x = self.bias_y = self.bias_z = 0.0
        self.last_time = time.time()
        self.bias_samples = []
        self.calibrated = False
        self._last_draw = 0.0
        self._draw_pending = False

    def _make_dial(self, parent, title, index):
        """Create beautiful circular dial with needle"""
        dial_frame = tk.Frame(parent, bg=BG)
        dial_frame.pack(pady=10)
        
        fig, ax = plt.subplots(figsize=(2.2, 2.2), subplot_kw={'aspect': 'equal'}, facecolor=BOX_BG)
        ax.set_facecolor(BOX_BG)
        ax.axis("off")

        # Outer circle
        circle = plt.Circle((0, 0), 1, color=GOLD, fill=False, linewidth=2)
        ax.add_artist(circle)

        # Ticks
        for ang in range(0, 360, 30):
            r_outer, r_inner = 0.95, 0.8
            x1, y1 = r_inner * np.cos(np.deg2rad(ang)), r_inner * np.sin(np.deg2rad(ang))
            x2, y2 = r_outer * np.cos(np.deg2rad(ang)), r_outer * np.sin(np.deg2rad(ang))
            ax.plot([x1, x2], [y1, y2], color=GOLD, linewidth=1.2)

        # Labels (0,90,180,270)
        for ang in [0, 90, 180, 270]:
            r = 1.35
            ax.text(r * np.cos(np.deg2rad(ang)), r * np.sin(np.deg2rad(ang)),
                    str(ang), ha="center", va="center",
                    fontsize=12, color=GOLD, fontweight="bold")

        # Needle
        needle, = ax.plot([0, 0], [0, 0.8], color=ACCENT, linewidth=3)

        # Title
        ax.text(0, -1.75, title, ha="center", va="center",
                fontsize=11, color=GOLD, fontweight="bold")

        ax.set_xlim(-1.5, 1.5)
        ax.set_ylim(-1.5, 1.5)

        canvas = FigureCanvasTkAgg(fig, master=dial_frame)
        canvas.draw()
        canvas.get_tk_widget().pack()
        
        self.dials.append({"needle": needle, "canvas": canvas})

    def _create_cylinder(self):
        # Create cylinder points
        z = np.linspace(-1, 1, 30)
        theta = np.linspace(0, 2 * np.pi, 60)
        theta_grid, z_grid = np.meshgrid(theta, z)
        
        # Cylinder coordinates
        x_grid = 0.5 * np.cos(theta_grid)
        y_grid = 0.5 * np.sin(theta_grid)
        
        self.cylinder_points = (x_grid, y_grid, z_grid)
        
        # Create end caps
        r = np.linspace(0, 0.5, 20)
        theta_cap = np.linspace(0, 2 * np.pi, 60)
        r_grid, theta_grid = np.meshgrid(r, theta_cap)
        
        x_top = r_grid * np.cos(theta_grid)
        y_top = r_grid * np.sin(theta_grid)
        z_top = np.ones_like(x_top)
        
        x_bottom = r_grid * np.cos(theta_grid)
        y_bottom = r_grid * np.sin(theta_grid)
        z_bottom = -np.ones_like(x_bottom)
        
        self.top_cap = (x_top, y_top, z_top)
        self.bottom_cap = (x_bottom, y_bottom, z_bottom)

    def _draw_static_frame(self):
        self.ax3d.clear()
        
        # Set limits and view
        self.ax3d.set_xlim(-1.5, 1.5)
        self.ax3d.set_ylim(-1.5, 1.5)
        self.ax3d.set_zlim(-1.5, 1.5)
        
        # Remove axes
        self.ax3d.set_xticks([])
        self.ax3d.set_yticks([])
        self.ax3d.set_zticks([])
        
        # Set initial view angle
        self.ax3d.view_init(elev=20, azim=45)
        
        # Draw coordinate system
        length = 1.2
        self.ax3d.quiver(0, 0, 0, length, 0, 0, color='red', linewidth=3, arrow_length_ratio=0.1)
        self.ax3d.quiver(0, 0, 0, 0, length, 0, color='green', linewidth=3, arrow_length_ratio=0.1)
        self.ax3d.quiver(0, 0, 0, 0, 0, length, color='blue', linewidth=3, arrow_length_ratio=0.1)
        
        # Add labels
        self.ax3d.text(length, 0, 0, "X", color='red', fontsize=12)
        self.ax3d.text(0, length, 0, "Y", color='green', fontsize=12)
        self.ax3d.text(0, 0, length, "Z", color='blue', fontsize=12)
        
        # Draw initial cylinder
        self._draw_cylinder()
        
        self.canvas.draw_idle()

    def _draw_cylinder(self):
        # Draw cylinder body with gradient color
        x, y, z = self.cylinder_points
        self.ax3d.plot_surface(x, y, z, alpha=0.8, color='cyan', edgecolor='white', linewidth=0.5)
        
        # Draw end caps
        x_top, y_top, z_top = self.top_cap
        x_bottom, y_bottom, z_bottom = self.bottom_cap
        
        self.ax3d.plot_surface(x_top, y_top, z_top, alpha=0.6, color='lightblue')
        self.ax3d.plot_surface(x_bottom, y_bottom, z_bottom, alpha=0.6, color='lightblue')

    def update_state(self, gyro_rate, timestamp_hw):
        # Fix: Use current time if timestamp is invalid
        if timestamp_hw == 0:
            now = time.time()
        else:
            now = timestamp_hw / 1000.0
            
        dt = now - self.last_time if self.last_time else 0.01
        self.last_time = now
        
        gx, gy, gz = gyro_rate
        
        # Calibration
        if not self.calibrated:
            self.bias_samples.append((gx, gy, gz))
            if len(self.bias_samples) >= 50:  # Reduced calibration samples for faster startup
                arr = np.array(self.bias_samples)
                self.bias_x, self.bias_y, self.bias_z = arr.mean(axis=0).tolist()
                self.calibrated = True
                print(f"Gyro bias calibrated: {self.bias_x:.3f}, {self.bias_y:.3f}, {self.bias_z:.3f}")
            return
        
        # Subtract bias and integrate
        gx -= self.bias_x
        gy -= self.bias_y
        gz -= self.bias_z
        
        if dt > 0:
            self.anglex += gx * dt * 57.2957795
            self.angley += gy * dt * 57.2957795
            self.anglez += gz * dt * 57.2957795
        
        # Update numeric labels immediately (no delay)
        for k, v in zip(("gx", "gy", "gz"), (gx, gy, gz)):
            self.gvars[k].set(f"{v:.3f}")
        for k, v in zip(("ax", "ay", "az"), (self.anglex, self.angley, self.anglez)):
            self.gvars[k].set(f"{v:.2f}")

        # Update needle dials immediately (no delay)
        self._update_dials()

    def _update_dials(self):
        """Update needle dials without delay"""
        if self.dials:
            # Convert angles to 0-360 range for dial display
            norm_anglex = self.anglex % 360
            norm_angley = self.angley % 360  
            norm_anglez = self.anglez % 360
            
            # Update needle positions
            self.dials[0]["needle"].set_data(
                [0, 0.7 * np.cos(np.radians(norm_anglex))],
                [0, 0.7 * np.sin(np.radians(norm_anglex))]
            )

            self.dials[1]["needle"].set_data(
                [0, 0.7 * np.cos(np.radians(norm_angley))],
                [0, 0.7 * np.sin(np.radians(norm_angley))]
            )

            self.dials[2]["needle"].set_data(
                [0, 0.7 * np.cos(np.radians(norm_anglez))],
                [0, 0.7 * np.sin(np.radians(norm_anglez))]
            )

            # Force redraw of dials
            for dial in self.dials:
                dial["canvas"].draw_idle()

    def request_draw(self):
        """Only used for 3D visualization throttling"""
        now_ms = time.time() * 1000.0
        if (now_ms - self._last_draw) >= GYRO_DRAW_MIN_MS:
            self._perform_3d_draw()
            self._last_draw = now_ms
            self._draw_pending = False
        elif not self._draw_pending:
            delay = int(max(1, GYRO_DRAW_MIN_MS - (now_ms - self._last_draw)))
            self._draw_pending = True
            self.root.after(delay, self._perform_3d_draw)

    def _perform_3d_draw(self):
        """Update 3D visualization (throttled)"""
        # Build rotation matrix
        rx, ry, rz = np.deg2rad(self.anglex), np.deg2rad(self.angley), np.deg2rad(self.anglez)
        
        Rx = np.array([[1, 0, 0], [0, np.cos(rx), -np.sin(rx)], [0, np.sin(rx), np.cos(rx)]])
        Ry = np.array([[np.cos(ry), 0, np.sin(ry)], [0, 1, 0], [-np.sin(ry), 0, np.cos(ry)]])
        Rz = np.array([[np.cos(rz), -np.sin(rz), 0], [np.sin(rz), np.cos(rz), 0], [0, 0, 1]])
        
        R = Rz @ Ry @ Rx

        # Clear and redraw
        self.ax3d.clear()
        
        # Set limits and view
        self.ax3d.set_xlim(-1.5, 1.5)
        self.ax3d.set_ylim(-1.5, 1.5)
        self.ax3d.set_zlim(-1.5, 1.5)
        self.ax3d.set_xticks([])
        self.ax3d.set_yticks([])
        self.ax3d.set_zticks([])
        self.ax3d.view_init(elev=20, azim=45)
        
        # Draw coordinate system
        length = 1.2
        self.ax3d.quiver(0, 0, 0, length, 0, 0, color='red', linewidth=3, arrow_length_ratio=0.1)
        self.ax3d.quiver(0, 0, 0, 0, length, 0, color='green', linewidth=3, arrow_length_ratio=0.1)
        self.ax3d.quiver(0, 0, 0, 0, 0, length, color='blue', linewidth=3, arrow_length_ratio=0.1)
        
        # Add labels
        self.ax3d.text(length, 0, 0, "X", color='red', fontsize=12)
        self.ax3d.text(0, length, 0, "Y", color='green', fontsize=12)
        self.ax3d.text(0, 0, length, "Z", color='blue', fontsize=12)

        # Rotate and draw cylinder
        self._draw_rotated_cylinder(R)
        
        self.canvas.draw_idle()
        self._draw_pending = False

    def _draw_rotated_cylinder(self, R):
        # Rotate cylinder points
        x, y, z = self.cylinder_points
        points = np.array([x.ravel(), y.ravel(), z.ravel()])
        rotated_points = R @ points
        
        x_rot = rotated_points[0, :].reshape(x.shape)
        y_rot = rotated_points[1, :].reshape(y.shape)
        z_rot = rotated_points[2, :].reshape(z.shape)
        
        # Draw rotated cylinder
        self.ax3d.plot_surface(x_rot, y_rot, z_rot, alpha=0.8, color='cyan', 
                              edgecolor='white', linewidth=0.5)
        
        # Rotate and draw end caps
        for cap_points in [self.top_cap, self.bottom_cap]:
            xc, yc, zc = cap_points
            points_cap = np.array([xc.ravel(), yc.ravel(), zc.ravel()])
            rotated_cap = R @ points_cap
            
            xc_rot = rotated_cap[0, :].reshape(xc.shape)
            yc_rot = rotated_cap[1, :].reshape(yc.shape)
            zc_rot = rotated_cap[2, :].reshape(zc.shape)
            
            self.ax3d.plot_surface(xc_rot, yc_rot, zc_rot, alpha=0.6, color='lightblue')

    def reset_orientation(self):
        self.anglex = self.angley = self.anglez = 0.0
        for k in ("ax", "ay", "az"):
            self.gvars[k].set("0.00")
        self._draw_pending = False
        self._last_draw = 0.0
        self._update_dials()  # Update dials immediately
        self._draw_static_frame()