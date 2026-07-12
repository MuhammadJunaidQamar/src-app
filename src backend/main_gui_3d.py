# main_gui_3d.py - Enhanced 3D GUI for CanSat with ESP32 Updates
import tkinter as tk
from tkinter import ttk
import time
import numpy as np
import matplotlib
matplotlib.use("TkAgg")
import matplotlib.pyplot as plt
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from collections import deque
from mpl_toolkits.mplot3d import Axes3D  # noqa

# ---------------- theme & throttles ----------------
BG = "#070814"
BOX_BG = "#0b1220"
ACCENT = "#00d4ff"
GOLD = "#FFD36E"
TEXT = "#dbeafe"

GYRO_DRAW_MIN_MS = 50  # Reduced delay for faster updates
GAUGE_DPI = 110

# ---------------- Mission GUI ----------------
class MissionGUI3D:
    def __init__(self, root):
        self.root = root
        
        style = ttk.Style(root)
        style.theme_use("clam")
        style.configure("TNotebook", background=BG, borderwidth=0)
        style.configure("TNotebook.Tab", background="#0d1524", foreground=TEXT, padding=[10, 6])
        style.map("TNotebook.Tab", background=[("selected", "#1d2b45")])

        nb = ttk.Notebook(root)
        nb.pack(fill="both", expand=True, padx=8, pady=8)

        frame_env = tk.Frame(nb, bg=BG)
        frame_gyro = tk.Frame(nb, bg=BG)

        nb.add(frame_env, text="Environment & Sensors")
        nb.add(frame_gyro, text="Gyro (3D Visualization)")

        self.environment = TabEnvironment(frame_env)
        self.gyro = TabGyro3D(frame_gyro)

    def on_new_packet(self, packet):
        try:
            self.environment.update_fields(packet)
        except Exception as e:
            print("Env update error:", e)
        
        try:
            # Get gyro values from packet
            gx = packet.get("gx", 0)
            gy = packet.get("gy", 0) 
            gz = packet.get("gz", 0)
            timestamp = packet.get("HardwareTimestamp", time.time() * 1000)
            self.gyro.update_state([gx, gy, gz], timestamp)
            self.gyro.request_draw()
        except Exception as e:
            print("Gyro update error:", e)

# ---------------- Environment Tab ----------------
class TabEnvironment:
    def __init__(self, parent):
        self.root = parent
        self.root.configure(bg=BG)
        self.buf_len = 200
        self.buffers = {
            k: deque([0.0]*self.buf_len, maxlen=self.buf_len)
            for k in ("temp", "press", "alt", "head", "ax", "ay", "az", 
                     "mx", "my", "mz", "roll", "pitch", "yaw", 
                     "sat", "lat", "lon", "distance", "totalDistance")
        }

        # Main title
        tk.Label(self.root, text="CanSat Sensor Dashboard", font=("Inter", 18, "bold"), 
                fg=ACCENT, bg=BG).pack(pady=8)

        # Create scrollable canvas for all sensors
        canvas_frame = tk.Frame(self.root, bg=BG)
        canvas_frame.pack(fill="both", expand=True, padx=10, pady=10)

        # Scrollbar
        scrollbar = tk.Scrollbar(canvas_frame, orient="vertical")
        scrollbar.pack(side="right", fill="y")

        # Canvas
        self.canvas = tk.Canvas(canvas_frame, bg=BG, yscrollcommand=scrollbar.set, highlightthickness=0)
        self.canvas.pack(side="left", fill="both", expand=True)
        scrollbar.config(command=self.canvas.yview)

        # Frame inside canvas
        self.scroll_frame = tk.Frame(self.canvas, bg=BG)
        self.canvas_window = self.canvas.create_window((0, 0), window=self.scroll_frame, anchor="nw")

        # Bind resize
        self.scroll_frame.bind("<Configure>", lambda e: self.canvas.configure(scrollregion=self.canvas.bbox("all")))
        self.canvas.bind("<Configure>", self._on_canvas_resize)

        # Mouse wheel scrolling
        self.canvas.bind_all("<MouseWheel>", self._on_mousewheel)

        # Define all sensors
        sensors = [
            # IMU Data
            {"key": "ax", "name": "Acceleration X", "unit": "m/s²", "range": [-20, 20], "color": "#FF6B6B"},
            {"key": "ay", "name": "Acceleration Y", "unit": "m/s²", "range": [-20, 20], "color": "#FF8E53"},
            {"key": "az", "name": "Acceleration Z", "unit": "m/s²", "range": [-20, 20], "color": "#FECA57"},
            
            # Orientation (NEW from ESP32)
            {"key": "roll", "name": "Roll", "unit": "°", "range": [-180, 180], "color": "#48DBFB"},
            {"key": "pitch", "name": "Pitch", "unit": "°", "range": [-180, 180], "color": "#0ABDE3"},
            {"key": "yaw", "name": "Yaw", "unit": "°", "range": [0, 360], "color": "#00D2D3"},
            
            # Magnetometer
            {"key": "mx", "name": "Magnetometer X", "unit": "µT", "range": [-100, 100], "color": "#5F27CD"},
            {"key": "my", "name": "Magnetometer Y", "unit": "µT", "range": [-100, 100], "color": "#341F97"},
            {"key": "mz", "name": "Magnetometer Z", "unit": "µT", "range": [-100, 100], "color": "#1B1464"},
            
            # Environment
            {"key": "temp", "name": "Temperature", "unit": "°C", "range": [-10, 60], "color": "#EE5A6F"},
            {"key": "press", "name": "Pressure", "unit": "Pa", "range": [80000, 110000], "color": "#45B7D1"},
            {"key": "alt", "name": "Altitude (Baro)", "unit": "m", "range": [-50, 500], "color": "#4ECDC4"},
            {"key": "head", "name": "Compass Heading", "unit": "°", "range": [0, 360], "color": "#96CEB4"},
            
            # GPS
            {"key": "sat", "name": "GPS Satellites", "unit": "count", "range": [0, 20], "color": "#F8B500"},
            {"key": "lat", "name": "Latitude", "unit": "°", "range": [-90, 90], "color": "#1DD1A1"},
            {"key": "lon", "name": "Longitude", "unit": "°", "range": [-180, 180], "color": "#10AC84"},
            
            # Distance (NEW from ESP32)
            {"key": "distance", "name": "Distance from Last", "unit": "m", "range": [0, 100], "color": "#FD79A8"},
            {"key": "totalDistance", "name": "Total Distance", "unit": "m", "range": [0, 5000], "color": "#FDCB6E"},
        ]

        self.cards = {}
        
        # Create two columns
        left_col = tk.Frame(self.scroll_frame, bg=BG)
        left_col.pack(side="left", fill="both", expand=True, padx=5)
        
        right_col = tk.Frame(self.scroll_frame, bg=BG)
        right_col.pack(side="right", fill="both", expand=True, padx=5)
        
        # Distribute sensors across columns
        for i, sensor in enumerate(sensors):
            parent_col = left_col if i < len(sensors) // 2 else right_col
            card = self._create_sensor_card(parent_col, sensor)
            self.cards[sensor["key"]] = card

        # Python timestamp tracking
        self.gui_time = 0.0
        self.powerup_time = 1000 * time.time()
        self.hwTimeOffset = 0.0

    def _on_canvas_resize(self, event):
        self.canvas.itemconfig(self.canvas_window, width=event.width)

    def _on_mousewheel(self, event):
        self.canvas.yview_scroll(int(-1*(event.delta/120)), "units")

    def _create_sensor_card(self, parent, sensor):
        card_frame = tk.Frame(parent, bg=BOX_BG, relief="ridge", bd=1, padx=10, pady=8)
        card_frame.pack(fill="x", pady=6, padx=5)

        # Header with sensor name
        header_frame = tk.Frame(card_frame, bg=BOX_BG)
        header_frame.pack(fill="x")
        
        tk.Label(header_frame, text=sensor["name"], font=("Inter", 11, "bold"), 
                fg=GOLD, bg=BOX_BG).pack(side="left")
        
        # Current value display
        value_var = tk.StringVar(value="0.00")
        value_label = tk.Label(header_frame, textvariable=value_var, font=("Inter", 12, "bold"),
                              fg=TEXT, bg=BOX_BG)
        value_label.pack(side="right")
        
        # Create the plot
        fig, ax = plt.subplots(figsize=(3.5, 1), dpi=80)
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
        ax.tick_params(colors=TEXT, labelsize=7)
        ax.set_ylabel(sensor["unit"], color=TEXT, fontsize=8)
        
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
        if self.gui_time == 0.0:
            self.gui_time = float(data.get("HardwareTimestamp", 0))
            self.hwTimeOffset = float(data.get("HardwareTimestamp", 0))
            self.powerup_time = 1000 * time.time()
            return self.gui_time
        else:
            self.gui_time = time.time() * 1000
            return self.gui_time - self.powerup_time + self.hwTimeOffset

    def update_fields(self, data):
        for key, card in self.cards.items():
            try:
                val = float(data.get(key, 0))
            except Exception:
                val = 0.0
            
            self.buffers[key].append(val)
            
            # Format value display
            if key in ["lat", "lon"]:
                card["val"].set(f"{val:.6f}")
            elif key in ["sat"]:
                card["val"].set(f"{int(val)}")
            else:
                card["val"].set(f"{val:.2f}")
            
            line = card["line"]
            line.set_ydata(self.buffers[key])
            
            # Auto-scale y-axis within sensor range
            arr = np.array(self.buffers[key])
            if len(arr) > 0:
                y_min = max(card["range"][0], arr.min() - 1)
                y_max = min(card["range"][1], arr.max() + 1)
                if y_max > y_min:
                    card["ax"].set_ylim(y_min, y_max)
            
            card["canvas"].draw_idle()

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
            ("gx", "Gx (rad/s)"), ("gy", "Gy (rad/s)"), ("gz", "Gz (rad/s)"),
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
        self.last_time = 0.0
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
        # Use current time if timestamp is invalid
        if timestamp_hw == 0:
            now = time.time()
        else:
            now = timestamp_hw / 1000.0
            
        if self.last_time == 0:
            self.last_time = now
            return
            
        dt = now - self.last_time
        self.last_time = now
        
        gx, gy, gz = gyro_rate
        
        # Calibration (first 50 samples)
        if not self.calibrated:
            self.bias_samples.append((gx, gy, gz))
            if len(self.bias_samples) >= 50:
                arr = np.array(self.bias_samples)
                self.bias_x, self.bias_y, self.bias_z = arr.mean(axis=0).tolist()
                self.calibrated = True
                print(f"✅ Gyro bias calibrated: X={self.bias_x:.3f}, Y={self.bias_y:.3f}, Z={self.bias_z:.3f}")
            return
        
        # Subtract bias and integrate
        gx -= self.bias_x
        gy -= self.bias_y
        gz -= self.bias_z
        
        if dt > 0 and dt < 1:  # Sanity check on dt
            self.anglex += gx * dt * 57.2957795  # rad/s to deg
            self.angley += gy * dt * 57.2957795
            self.anglez += gz * dt * 57.2957795
        
        # Update numeric labels
        for k, v in zip(("gx", "gy", "gz"), (gx, gy, gz)):
            self.gvars[k].set(f"{v:.3f}")
        for k, v in zip(("ax", "ay", "az"), (self.anglex, self.angley, self.anglez)):
            self.gvars[k].set(f"{v:.2f}")

        # Update needle dials immediately
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
        self._update_dials()
        self._draw_static_frame()



