import os
from PIL import Image

upload_dir = r"C:\Users\Aman Kumar\.gemini\antigravity-ide\brain\3c05e1a9-1efd-4f98-b76c-8a90dbd5c424\.user_uploaded"
styleboard_path = os.path.join(upload_dir, "media_1791047669315.jpg")
splash_path = os.path.join(upload_dir, "media_1791047704685.png")

assets_dir = r"c:\Users\Aman Kumar\OneDrive\Desktop\s60inventory\assets"
os.makedirs(assets_dir, exist_ok=True)

if os.path.exists(styleboard_path):
    img_sb = Image.open(styleboard_path)
    print("Styleboard size:", img_sb.size)
    img_sb.save(os.path.join(assets_dir, "s60_styleboard.jpg"))
    
    # 1. SVIET Logo
    sviet_logo = img_sb.crop((25, 60, 160, 215))
    sviet_logo.save(os.path.join(assets_dir, "sviet_logo.png"))
    
    # 2. S60 Logo
    s60_logo = img_sb.crop((180, 50, 360, 215))
    s60_logo.save(os.path.join(assets_dir, "s60_logo.png"))
    
    # 3. App Icon (Dark Background S60 + Box)
    app_icon = img_sb.crop((500, 65, 595, 195))
    app_icon.save(os.path.join(assets_dir, "app_icon.png"))
    
    # 4. Small Favicon (Orange Box with s60 badge)
    favicon = img_sb.crop((820, 80, 895, 185))
    favicon.save(os.path.join(assets_dir, "favicon.png"))
    
    # 5. Full Horizontal Lockup (from section 6)
    # Section 6: y approx 570 to 710, x: 180 to 440
    # Let's crop s60 flame symbol
    s60_symbol = img_sb.crop((615, 75, 680, 185))
    s60_symbol.save(os.path.join(assets_dir, "s60_symbol.png"))


if os.path.exists(splash_path):
    img_sp = Image.open(splash_path)
    print("Splash size:", img_sp.size)
    img_sp.save(os.path.join(assets_dir, "sviet_splash_screen.png"))
    
    # In splash screen (width, height), let's crop the header logos and the campus building
    w, h = img_sp.size
    # Crop logos area at top: approx y: 0.05 to 0.18, x: 0.1 to 0.9
    top_logos = img_sp.crop((int(w * 0.08), int(h * 0.06), int(w * 0.92), int(h * 0.17)))
    top_logos.save(os.path.join(assets_dir, "sviet_s60_header_logos.png"))
    
    # Crop campus building: approx y: 0.45 to 0.80
    campus = img_sp.crop((int(w * 0.0), int(h * 0.45), int(w * 1.0), int(h * 0.80)))
    campus.save(os.path.join(assets_dir, "sviet_campus.png"))

print("Extracted assets saved to:", assets_dir)
