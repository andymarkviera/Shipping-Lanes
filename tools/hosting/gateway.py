"""Bounded HTTPS front door for invited-player testing. Never proxies authority/admin."""
import collections, http.client, json, socket, socketserver, ssl, sys, threading, time
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import urlsplit

class Limits:
    def __init__(self): self.rows=collections.OrderedDict(); self.lock=threading.Lock()
    def allow(self, ip, kind, now=None):
        now=time.monotonic() if now is None else now
        with self.lock:
            # Global budget also bounds a flood spread across addresses.
            for key, maximum in [(('*',kind),600 if kind=='get' else 120),((ip,kind),240 if kind=='get' else 20)]:
                row=self.rows.get(key)
                if row is None or now-row[0]>=60: row=[now,0]; self.rows[key]=row
                if row[1]>=maximum: return False
            self.rows[('*',kind)][1]+=1; self.rows[(ip,kind)][1]+=1
            self.rows.move_to_end((ip,kind)); self.rows.move_to_end(('*',kind))
            while len(self.rows)>4096: self.rows.popitem(last=False)
            return True

class Server(socketserver.ThreadingMixIn, HTTPServer):
    daemon_threads=True
    def __init__(self, address, handler, context):
        self.context=context; self.slots=threading.BoundedSemaphore(32)
        super().__init__(address,handler)
    def process_request(self, request, address):
        if not self.slots.acquire(False): request.close(); return
        try: super().process_request(request,address)
        except Exception: self.slots.release(); raise
    def process_request_thread(self, request, address):
        try:
            request.settimeout(8)
            request=self.context.wrap_socket(request,server_side=True)
            self.finish_request(request,address)
        except (OSError, ValueError): pass
        finally: self.shutdown_request(request); self.slots.release()

def route(method, path):
    parsed=urlsplit(path)
    if parsed.scheme or parsed.netloc or len(path)>8192 or '%' in parsed.path or '..' in parsed.path or '\\' in parsed.path: return None
    if parsed.path=='/v1/ticket' and method=='POST': return 'authority'
    if parsed.path.startswith('/resources/') and method=='GET': return 'provider'
    prefix='/realms/shipping-local/'
    allowed=('protocol/openid-connect/', 'login-actions/', '.well-known/')
    if method in ('GET','POST') and any(parsed.path.startswith(prefix+x) for x in allowed): return 'provider'
    return None

def main(path):
    c=json.loads(Path(path).read_text(encoding='utf-8')); limits=Limits()
    client_tls=ssl.create_default_context(cafile=c['certificate'])
    class Handler(BaseHTTPRequestHandler):
        def log_message(self,*args): pass  # Never log bearer tokens, codes or credentials.
        def reply(self,status,data=b'',headers=()):
            print('GATEWAY_RESPONSE', self.command, status, flush=True)
            self.send_response(status)
            for key,value in headers:
                if key.lower() not in ('connection','transfer-encoding','content-length','server','date'): self.send_header(key,value)
            self.send_header('Content-Length',str(len(data))); self.send_header('Connection','close')
            self.send_header('X-Content-Type-Options','nosniff')
            self.end_headers(); self.wfile.write(data); self.close_connection=True
        def do_GET(self): self.forward()
        def do_POST(self): self.forward()
        def forward(self):
            target=route(self.command,self.path)
            if not target: self.reply(404); return
            if self.headers.get('Host') not in (c['host']+':'+str(c['port']), c['host'] if c['port']==443 else ''):
                self.reply(400); return
            kind='get' if self.command=='GET' else 'post'
            lengths=self.headers.get_all('Content-Length',[])
            if self.headers.get('Transfer-Encoding') or len(lengths)>1: self.reply(400); return
            try: size=int(lengths[0]) if lengths else 0
            except ValueError: self.reply(400); return
            if size<0 or size>32768 or (self.command=='GET' and size): self.reply(413); return
            upstream=None
            try:
                body=self.rfile.read(size)
                if len(body)!=size: self.reply(400); return
                if not limits.allow(self.client_address[0],kind): self.reply(429,headers=[('Retry-After','60')]); return
                headers={k:v for k,v in self.headers.items() if k.lower() in ('content-type','authorization','cookie','accept','accept-language','user-agent','origin','referer')}
                headers['Host']=c['host']+':'+str(c['port'])
                upstream=http.client.HTTPSConnection('127.0.0.1',c[target+'_port'],context=client_tls,timeout=8)
                upstream.request(self.command,self.path,body=body,headers=headers)
                response=upstream.getresponse(); data=response.read(8*1024*1024+1)
                if len(data)>8*1024*1024: self.reply(502); return
                self.reply(response.status,data,response.getheaders())
            except (OSError,http.client.HTTPException):
                try: self.reply(503)
                except OSError: pass
            finally:
                if upstream: upstream.close()
    tls=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER); tls.minimum_version=ssl.TLSVersion.TLSv1_2
    tls.load_cert_chain(c['certificate'],c['key'])
    server=Server((c['bind'],c['port']),Handler,tls)
    Path(c['ready']).write_text(str(server.server_port))
    server.serve_forever()

if __name__=='__main__': main(sys.argv[1])
