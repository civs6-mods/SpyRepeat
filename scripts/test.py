from pathlib import Path
import subprocess,os
r=Path(__file__).resolve().parents[1];g=r/'tests/generated';g.mkdir(exist_ok=True)
node=os.environ.get('NODE','node');cli=os.environ.get('FENGARI_CLI',str(r/'node_modules/fengari-node-cli/src/lua-cli.js'))
def run(p,marker):
 result=subprocess.run([node,cli,str(p)],cwd=r,capture_output=True,text=True,encoding='utf8')
 assert result.returncode==0 and not result.stderr.strip() and marker in result.stdout,result.stdout+result.stderr
 print(marker)
(g/'syntax.lua').write_text('\n'.join('assert(loadfile("mod/'+p.name+'"));' for p in (r/'mod').glob('*.lua'))+'\nprint("Syntax passed");',encoding='utf8')
run(g/'syntax.lua','Syntax passed')
run(r/'tests/interaction.lua','SpyRepeat interaction regression passed')
fixture=(r/'tests/interaction.lua').read_text(encoding='utf8').split('local w = Fixture(); w:enable();')[0]
(g/'redesign.lua').write_text(fixture+(r/'tests/redesign.lua').read_text(encoding='utf8'),encoding='utf8')
run(g/'redesign.lua','SpyRepeat redesign regression passed')
run(r/'tests/native_adapters.lua','SpyRepeat native adapter regression passed')
run(r/'tests/outcome.lua','Spy outcome regression passed')
for name,marker in [('pending_escape','Spy pending-escape regression passed'),('inline','Spy overview cleanup regression passed')]:
 source=(r/'mod/SpyRepeat.lua').read_text(encoding='utf8')
 (g/(name+'.lua')).write_text('SPY_REPEAT_SOURCE = [======[\n'+source+']======];\n'+(r/'tests'/(name+'.lua')).read_text(encoding='utf8'),encoding='utf8')
 run(g/(name+'.lua'),marker)
