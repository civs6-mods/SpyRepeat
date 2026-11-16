from pathlib import Path
import json,hashlib,xml.etree.ElementTree as ET,re
r=Path(__file__).resolve().parents[1];src=r/'mod'
m=json.loads((r/'release-manifest.json').read_text())
actual={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in src.iterdir() if p.is_file()}
assert actual==m['files'], 'Release hashes differ; update the manifest for intentional changes'
xml=ET.parse(src/'SpyRepeat.modinfo').getroot()
assert xml.get('id')==m['modId'] and int(xml.get('version'))==m['manifestVersion']
for p in src.glob('*.xml'):ET.parse(p)
for e in xml.findall('./Files/File'):assert (src/e.text).is_file()
for e in xml.findall('./InGameActions/ReplaceUIScript/Properties/LuaReplace'):assert (src/e.text).is_file()
tags=[(e.get('Tag'),e.get('Language')) for e in ET.parse(src/'Text.xml').findall('./LocalizedText/Row')]
assert len(tags)==len(set(tags))
for p in [*src.glob('*.lua'),src/'SpyRepeat.xml']:
 for tag in re.findall(r'LOC_SR_[A-Z_]+',p.read_text(encoding='utf8')):
  assert (tag,'zh_Hans_CN') in tags and (tag,'en_US') in tags,tag
print('Verified 11 release files, hashes, XML, manifest and localization')
