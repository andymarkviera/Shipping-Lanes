"""Independent port loading/approach checks with optional rendered overviews."""
import argparse,json,os,subprocess,uuid
from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--runtime',choices=['editor','release'],default='editor');p.add_argument('--capture',action='store_true');a=p.parse_args()
folder=root.parent/'output/ports'/uuid.uuid4().hex[:8];folder.mkdir(parents=True)
exe=root.parent/'output/tools/godot-4.7.2/godot.windows.opt.tools.64.exe' if a.runtime=='editor' else root/'exports/windows-x86_64/release/ShippingLanes.exe'
args=[str(exe)]+(['--max-fps','60'] if a.capture else ['--headless'])
if a.runtime=='editor':args+=['--path',str(root)]
args+=['--','--ports-check']
if a.capture:args+=['--port-capture='+str(folder/'port')]
env=os.environ.copy();env['APPDATA']=str(folder/'user')
startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=subprocess.SW_HIDE
result=subprocess.run(args,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=40,creationflags=subprocess.CREATE_NO_WINDOW,startupinfo=startup)
output=result.stdout.decode('utf-8',errors='replace');(folder/'godot.log').write_text(output,encoding='utf-8')
passed=result.returncode==0 and 'PORTS_PASS' in output and 'ERROR:' not in output
(folder/'summary.json').write_text(json.dumps(dict(passed=passed,runtime=a.runtime,capture=a.capture,exit_code=result.returncode),indent=2))
print(output);print('Evidence:',folder)
raise SystemExit(0 if passed else 1)
