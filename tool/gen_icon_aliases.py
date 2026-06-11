#!/usr/bin/env python3
"""Genera/regenera los <activity-alias> del ícono de la app en el AndroidManifest.

El ícono del lanzador se conmuta en runtime habilitando/deshabilitando
activity-alias (PackageManager.setComponentEnabledSetting). Este script:

  1. Quita el intent-filter LAUNCHER de la MainActivity (el punto de entrada pasa
     a vivir en el alias por defecto, así MainActivity nunca se deshabilita).
  2. Inserta, entre los marcadores AppIconStart/AppIconEnd:
       - AppIconDefault (habilitado): ícono adaptativo por defecto.
       - AppIcon_<tema> (deshabilitados): uno por cada drawable ic_app_<tema>.

Idempotente: regenerable cuantas veces se quiera. Las claves se derivan de los
drawables `res/drawable-nodpi/ic_app_*.png`.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
MANIFEST = os.path.join(ROOT, 'android/app/src/main/AndroidManifest.xml')
DRAW = os.path.join(ROOT, 'android/app/src/main/res/drawable-nodpi')
PKG = 'com.nbsound.nb_sound_mobile'

LAUNCHER_FILTER = re.compile(
    r'\n[ \t]*<intent-filter>\s*'
    r'<action android:name="android\.intent\.action\.MAIN"\s*/>\s*'
    r'<category android:name="android\.intent\.category\.LAUNCHER"\s*/>\s*'
    r'</intent-filter>',
    re.S,
)

BLOCK_RE = re.compile(r'[ \t]*<!-- AppIconStart -->.*?<!-- AppIconEnd -->\n',
                      re.S)


def keys():
    ks = []
    for f in sorted(os.listdir(DRAW)):
        m = re.fullmatch(r'ic_app_(.+)\.png', f)
        if m:
            ks.append(m.group(1))
    return ks


def alias(name, icon, enabled):
    return (
        f'        <activity-alias\n'
        f'            android:name="{PKG}.{name}"\n'
        f'            android:enabled="{"true" if enabled else "false"}"\n'
        f'            android:exported="true"\n'
        f'            android:targetActivity=".MainActivity"\n'
        f'            android:icon="{icon}">\n'
        f'            <intent-filter>\n'
        f'                <action android:name="android.intent.action.MAIN"/>\n'
        f'                <category android:name="android.intent.category.LAUNCHER"/>\n'
        f'            </intent-filter>\n'
        f'        </activity-alias>\n'
    )


def main():
    ks = keys()
    assert len(ks) == 63, f'esperaba 63 iconos, hay {len(ks)}'
    with open(MANIFEST, encoding='utf-8') as fh:
        xml = fh.read()

    # 1) Quitar el LAUNCHER de la MainActivity (solo dentro del <activity>).
    act_open = xml.index('<activity\n')
    act_close = xml.index('</activity>', act_open)
    head, body, tail = xml[:act_open], xml[act_open:act_close], xml[act_close:]
    body = LAUNCHER_FILTER.sub('', body)
    xml = head + body + tail

    # 2) Construir el bloque de alias.
    lines = ['        <!-- AppIconStart -->',
             '        <!-- Generado por tool/gen_icon_aliases.py; no editar a mano. -->']
    lines.append(alias('AppIconDefault', '@mipmap/ic_launcher', True).rstrip('\n'))
    for k in ks:
        lines.append(alias(f'AppIcon_{k}', f'@drawable/ic_app_{k}', False).rstrip('\n'))
    lines.append('        <!-- AppIconEnd -->')
    block = '\n'.join(lines) + '\n'

    # 3) Reemplazar bloque existente o insertarlo antes de </application>.
    if BLOCK_RE.search(xml):
        xml = BLOCK_RE.sub(block, xml)
    else:
        idx = xml.index('    </application>')
        xml = xml[:idx] + block + '\n' + xml[idx:]

    with open(MANIFEST, 'w', encoding='utf-8') as fh:
        fh.write(xml)
    print(f'Manifest actualizado con {len(ks)} alias de ícono (+ default).')


if __name__ == '__main__':
    sys.exit(main())
