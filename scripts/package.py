from pathlib import Path
import subprocess,sys,json,zipfile
r=Path(__file__).resolve().parents[1]
subprocess.run([sys.executable,str(r/'scripts/verify.py')],check=True)
m=json.loads((r/'release-manifest.json').read_text())
out=r/'dist'/('SpyRepeat-'+m['version']+'.zip');out.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
 for name in m['files']:z.write(r/'mod'/name,'SpyRepeat/'+name)
with zipfile.ZipFile(out) as z:assert z.testzip() is None
print(out)
