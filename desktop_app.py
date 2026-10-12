import os
import sys
import json
import time
import socket
import shutil
import threading
import urllib.request
import webview

# Configure base and data paths
if getattr(sys, "frozen", False):
    EXE_DIR = os.path.dirname(sys.executable)
    BUNDLE_DIR = sys._MEIPASS
else:
    EXE_DIR = os.path.dirname(os.path.abspath(__file__))
    BUNDLE_DIR = EXE_DIR

# Config file for centralized server connection
CONFIG_FILE = os.path.join(EXE_DIR, "s60_config.json")

def load_config():
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            print(f"[Desktop App] Warning loading config: {e}")
    return {}

def save_config(cfg):
    try:
        with open(CONFIG_FILE, "w", encoding="utf-8") as f:
            json.dump(cfg, f, indent=2)
    except Exception as e:
        print(f"[Desktop App] Warning saving config: {e}")

def init_local_backend():
    """Initializes local SQLite database and backend environment if needed."""
    backend_dir = os.path.join(BUNDLE_DIR, "backend")
    if backend_dir not in sys.path:
        sys.path.insert(0, backend_dir)

    db_path = os.path.join(EXE_DIR, "s60inventory.db")
    if not os.path.exists(db_path):
        seed_db = os.path.join(BUNDLE_DIR, "backend", "s60inventory.db")
        if os.path.exists(seed_db):
            try:
                shutil.copy2(seed_db, db_path)
                print(f"[Desktop App] Seed database copied to {db_path}")
            except Exception as e:
                print(f"[Desktop App] Could not copy seed db: {e}")

    os.environ["DATABASE_URL"] = f"sqlite:///{os.path.abspath(db_path).replace(os.sep, '/')}"

def find_free_port(preferred_port=8000):
    """Check if preferred port is free; if not, find an open port."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        if s.connect_ex(("127.0.0.1", preferred_port)) != 0:
            return preferred_port
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]

class UvicornThread(threading.Thread):
    def __init__(self, host: str, port: int):
        super().__init__(daemon=True)
        self.host = host
        self.port = port
        init_local_backend()
        from app.main import app
        import uvicorn
        config = uvicorn.Config(
            app=app,
            host=host,
            port=port,
            log_level="warning",
            access_log=False
        )
        self.server = uvicorn.Server(config)

    def run(self):
        self.server.run()

    def stop(self):
        self.server.should_exit = True

def wait_for_server(url: str, timeout_sec: int = 15):
    """Wait until backend server responds to health check."""
    start_time = time.time()
    while time.time() - start_time < timeout_sec:
        try:
            with urllib.request.urlopen(url, timeout=1) as response:
                if response.status == 200:
                    return True
        except Exception:
            time.sleep(0.2)
    return False

class DesktopApi:
    def __init__(self):
        self.window = None

    def set_window(self, window):
        self.window = window

    def save_file_dialog(self, filename: str, content: str):
        """
        Pops up a native Windows Save As dialog.
        Saves true binary Excel workbooks (.xlsx) or UTF-8 BOM CSV files.
        """
        try:
            import base64
            is_xlsx = filename.lower().endswith(".xlsx")
            dialog_type = getattr(webview.FileDialog, 'SAVE', 30) if hasattr(webview, 'FileDialog') else 30
            if is_xlsx:
                file_types = ('Excel Workbooks (*.xlsx)', 'All files (*.*)')
            else:
                file_types = ('CSV Files (*.csv)', 'All files (*.*)')
            
            downloads_dir = os.path.join(os.path.expanduser("~"), "Downloads")
            if not os.path.exists(downloads_dir):
                downloads_dir = os.path.join(os.path.expanduser("~"), "Desktop")

            chosen_path = None
            if self.window:
                res = self.window.create_file_dialog(
                    dialog_type=dialog_type,
                    directory=downloads_dir,
                    save_filename=filename,
                    file_types=file_types
                )
                if not res:
                    return {"success": False, "cancelled": True}
                chosen_path = res[0] if isinstance(res, (list, tuple)) else res

            if not chosen_path:
                chosen_path = os.path.join(downloads_dir, filename)

            if is_xlsx:
                if not chosen_path.lower().endswith(".xlsx"):
                    chosen_path += ".xlsx"
                # Decode base64 binary content
                b64_str = content
                if "," in b64_str:
                    b64_str = b64_str.split(",", 1)[1]
                raw_bytes = base64.b64decode(b64_str)
                with open(chosen_path, "wb") as f:
                    f.write(raw_bytes)
            else:
                if not chosen_path.lower().endswith(".csv"):
                    chosen_path += ".csv"
                with open(chosen_path, "w", encoding="utf-8-sig", newline="") as f:
                    f.write(content)

            return {"success": True, "saved_path": chosen_path}
        except Exception as e:
            try:
                downloads_dir = os.path.join(os.path.expanduser("~"), "Downloads")
                fallback_path = os.path.join(downloads_dir, filename)
                if filename.lower().endswith(".xlsx"):
                    import base64
                    b64_str = content
                    if "," in b64_str:
                        b64_str = b64_str.split(",", 1)[1]
                    raw_bytes = base64.b64decode(b64_str)
                    with open(fallback_path, "wb") as f:
                        f.write(raw_bytes)
                else:
                    with open(fallback_path, "w", encoding="utf-8-sig", newline="") as f:
                        f.write(content)
                return {"success": True, "saved_path": fallback_path, "fallback": True}
            except Exception as e2:
                return {"success": False, "error": str(e2)}

    def get_server_config(self):
        return load_config()

    def set_server_url(self, new_url: str):
        cfg = load_config()
        cfg["server_url"] = new_url.strip().rstrip("/")
        save_config(cfg)
        return {"success": True, "server_url": cfg["server_url"]}

def main():
    cfg = load_config()
    server_url = cfg.get("server_url", "").strip().rstrip("/")
    if not server_url:
        server_url = os.environ.get("S60_SERVER_URL", "").strip().rstrip("/")

    # Support command line server argument
    if len(sys.argv) > 1 and sys.argv[1].startswith(("http://", "https://")):
        server_url = sys.argv[1].strip().rstrip("/")

    is_cloud = bool(
        server_url
        and server_url.startswith(("http://", "https://"))
        and "127.0.0.1" not in server_url
        and "localhost" not in server_url
    )

    server_thread = None
    if is_cloud:
        print(f"[Desktop App] Connecting to Central Cloud Server: {server_url}")
        portal_url = f"{server_url}/portal/?_t={int(time.time())}"
    else:
        # Standalone / Offline Local Server Mode
        port = find_free_port(8000)
        host = "0.0.0.0"
        server_thread = UvicornThread(host, port)
        server_thread.start()

        health_url = f"http://127.0.0.1:{port}/health"
        portal_url = f"http://127.0.0.1:{port}/portal/?_t={int(time.time())}"

        ready = wait_for_server(health_url, timeout_sec=15)
        if not ready:
            print("[Desktop App] Backend server failed to start within timeout.")

    # Find icon path
    icon_path = os.path.join(BUNDLE_DIR, "assets", "app_icon.ico")
    if not os.path.exists(icon_path):
        icon_path = os.path.join(BUNDLE_DIR, "assets", "app_icon.png")

    desktop_api = DesktopApi()

    # Create PyWebView native desktop window with DesktopApi bridge
    window = webview.create_window(
        title="S60 Inventory & Rewards Management System",
        url=portal_url,
        width=1320,
        height=860,
        min_size=(1024, 680),
        text_select=True,
        zoomable=True,
        js_api=desktop_api
    )
    desktop_api.set_window(window)

    # Start the native window (blocks until user closes window)
    try:
        webview.start(debug=False, private_mode=True)
    finally:
        if server_thread:
            server_thread.stop()

if __name__ == "__main__":
    main()
