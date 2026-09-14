#!/usr/bin/env python3
"""Select a compact and a large installed iPhone without hard-coding runtime UUIDs."""
import json
import sys
all_devices = [device for group in json.load(sys.stdin)['devices'].values() for device in group
               if 'iPhone' in device['name'] and device.get('isAvailable', True)]
assert all_devices, 'Install an iOS Simulator runtime first'
compact = next((d for d in reversed(all_devices) if 'SE' in d['name']), None)
if compact is None:
    compact = next((d for d in reversed(all_devices) if 'Pro' not in d['name'] and 'Plus' not in d['name']), all_devices[0])
large = next((d for d in reversed(all_devices) if 'Pro Max' in d['name']), all_devices[-1])
for d in {compact['udid']: compact, large['udid']: large}.values():
    print(d['udid'])
    print(f"Testing {d['name']} ({d['udid']})", file=sys.stderr)
