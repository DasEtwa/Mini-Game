#!/usr/bin/env python3
"""Check the device archive, bundle structure, executable and embedded Swift module."""
import plistlib
import sys
import zipfile
with zipfile.ZipFile(sys.argv[1]) as ipa:
    prefix = 'Payload/RackAndRich.app/'
    info = plistlib.loads(ipa.read(prefix + 'Info.plist'))
    assert info['CFBundleIdentifier'] == 'de.dasetwa.rackandrich'
    assert info['CFBundleShortVersionString'] == '0.2.0'
    assert info['CFBundleSupportedPlatforms'] == ['iPhoneOS']
    assert info['MinimumOSVersion'] == '17.0'
    binary = ipa.read(prefix + info['CFBundleExecutable'])
    assert binary[:4] in (b'\xcf\xfa\xed\xfe', b'\xca\xfe\xba\xbe'), 'Expected Mach-O device executable'
    assert prefix + 'Frameworks/TycoonCore.framework/TycoonCore' in ipa.namelist()
    assert not any('..' in name.split('/') for name in ipa.namelist())
    assert ipa.testzip() is None
    print('IPA verified: device bundle, executable, core framework, version and ZIP integrity.')
