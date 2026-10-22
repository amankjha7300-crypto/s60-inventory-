# -*- mode: python ; coding: utf-8 -*-

import os
import sys
from PyInstaller.utils.hooks import collect_data_files, collect_submodules

block_cipher = None

# Bundle web portal, assets, backend modules, and cloud config
datas = [
    ('web', 'web'),
    ('assets', 'assets'),
    ('backend', 'backend'),
    ('s60_config.json', '.'),
]

# Hidden imports required by dynamic ASGI / FastAPI / SQLAlchemy / PyWebView
hiddenimports = [
    'uvicorn',
    'uvicorn.logging',
    'uvicorn.loops',
    'uvicorn.loops.auto',
    'uvicorn.protocols',
    'uvicorn.protocols.http',
    'uvicorn.protocols.http.auto',
    'uvicorn.protocols.websockets',
    'uvicorn.protocols.websockets.auto',
    'uvicorn.lifespans',
    'uvicorn.lifespans.on',
    'uvicorn.lifespans.off',
    'fastapi',
    'fastapi.staticfiles',
    'fastapi.middleware.cors',
    'fastapi.responses',
    'pydantic',
    'pydantic_settings',
    'pydantic_core',
    'sqlalchemy',
    'sqlalchemy.dialects.sqlite',
    'starlette',
    'starlette.staticfiles',
    'starlette.routing',
    'starlette.middleware',
    'starlette.middleware.cors',
    'jwt',
    'bcrypt',
    'email_validator',
    'webview',
    'webview.platforms.winforms',
    'webview.platforms.edgechromium',
    'clr_loader',
    'pythonnet',
    'bottle',
    'app',
    'app.main',
    'app.core',
    'app.core.config',
    'app.core.security',
    'app.database',
    'app.database.session',
    'app.database.seed',
    'app.models',
    'app.models.all_models',
    'app.schemas',
    'app.schemas.schemas',
    'app.api',
    'app.api.deps',
    'app.api.v1',
    'app.api.v1.academic',
    'app.api.v1.auth',
    'app.api.v1.dashboard',
    'app.api.v1.distribution',
    'app.api.v1.events',
    'app.api.v1.inventory',
    'app.api.v1.reports',
    'app.api.v1.students',
    'app.api.v1.system',
    'openpyxl',
    'openpyxl.styles',
    'openpyxl.utils',
    'et_xmlfile',
]

try:
    hiddenimports += collect_submodules('uvicorn')
    hiddenimports += collect_submodules('fastapi')
    hiddenimports += collect_submodules('starlette')
    hiddenimports += collect_submodules('pydantic')
    hiddenimports += collect_submodules('sqlalchemy')
    hiddenimports += collect_submodules('webview')
    hiddenimports += collect_submodules('openpyxl')
except Exception as e:
    print(f"Notice during submodule collection: {e}")

icon_file = os.path.abspath(os.path.join('assets', 'app_icon.ico'))
if not os.path.exists(icon_file):
    icon_file = None

a = Analysis(
    ['desktop_app.py'],
    pathex=['.', 'backend'],
    binaries=[],
    datas=datas,
    hiddenimports=list(set(hiddenimports)),
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='S60_Inventory',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=icon_file,
)
