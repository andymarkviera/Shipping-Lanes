"""Native authorization-code/PKCE protocol proof. No password grant or client secret."""
import base64, hashlib, html, http.cookiejar, http.server, json, secrets, ssl, threading, time
import urllib.request, urllib.parse, urllib.error
from html.parser import HTMLParser
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import rsa, padding

def b64(data): return base64.urlsafe_b64encode(data).rstrip(b'=').decode()
def decode(text): return base64.urlsafe_b64decode(text+'='*(-len(text)%4))

def validate_jwt(token, jwks, issuer, audience, nonce=None, now=None):
    if not isinstance(token,str) or len(token)>32768: raise ValueError('invalid token')
    h,p,s=token.split('.')
    header=json.loads(decode(h)); claims=json.loads(decode(p))
    if header.get('alg')!='RS256':raise ValueError('algorithm')
    keys=[k for k in jwks['keys'] if k.get('kid')==header.get('kid') and k.get('kty')=='RSA' and k.get('use')=='sig' and k.get('alg')=='RS256']
    if len(keys)!=1:raise ValueError('key')
    key=keys[0];public=rsa.RSAPublicNumbers(int.from_bytes(decode(key['e']),'big'),int.from_bytes(decode(key['n']),'big')).public_key()
    public.verify(decode(s),(h+'.'+p).encode(),padding.PKCS1v15(),hashes.SHA256())
    now=time.time() if now is None else now
    aud=claims.get('aud');aud=[aud] if isinstance(aud,str) else aud
    if claims.get('iss')!=issuer or not isinstance(aud,list) or audience not in aud:raise ValueError('issuer/audience')
    if not isinstance(claims.get('exp'),int) or claims['exp']<=now or claims.get('nbf',0)>now or claims.get('iat',0)>now+30:raise ValueError('time')
    if not isinstance(claims.get('sub'),str) or not claims['sub']:raise ValueError('subject')
    if nonce is not None and not secrets.compare_digest(claims.get('nonce',''),nonce):raise ValueError('nonce')
    return claims

class NativeFlow:
    def __init__(self,issuer,ca):
        self.issuer=issuer;self.context=ssl.create_default_context(cafile=str(ca))
        self.state=secrets.token_urlsafe(32);self.nonce=secrets.token_urlsafe(32);self.verifier=secrets.token_urlsafe(48)
        self.code=None;self.used=False;self.deadline=0;flow=self
        class Callback(http.server.BaseHTTPRequestHandler):
            def log_message(self,*args):pass
            def do_GET(self):
                parsed=urllib.parse.urlsplit(self.path);query=urllib.parse.parse_qs(parsed.query)
                valid=(parsed.path=='/callback' and not flow.used and time.monotonic()<flow.deadline and len(query.get('state',[]))==1 and secrets.compare_digest(query['state'][0],flow.state) and len(query.get('code',[]))==1 and 'error' not in query)
                flow.callback_diagnostic={'keys':sorted(query),'state_ok':query.get('state')==[flow.state],'code_count':len(query.get('code',[])),'error':query.get('error',[])}
                if valid:flow.code=query['code'][0];flow.used=True
                self.send_response(200 if valid else 400);self.send_header('Content-Type','text/plain');self.end_headers();self.wfile.write(b'Return to the game.' if valid else b'Sign-in callback rejected.')
        self.callback=http.server.HTTPServer(('127.0.0.1',0),Callback)
        self.thread=threading.Thread(target=self.callback.serve_forever,daemon=True);self.thread.start()
        self.redirect='http://127.0.0.1:%d/callback'%self.callback.server_port
    def discovery(self):
        data=self.get_json(self.issuer+'/.well-known/openid-configuration')
        if data['issuer']!=self.issuer:raise ValueError('issuer discovery mismatch')
        for key in ['authorization_endpoint','token_endpoint','jwks_uri']:
            if not data[key].startswith(self.issuer+'/'):raise ValueError('endpoint origin')
        return data
    def get_json(self,url):
        with urllib.request.urlopen(url,context=self.context,timeout=10) as r:return json.load(r)
    def authorization_url(self):
        self.deadline=time.monotonic()+60
        return self.discovery()['authorization_endpoint']+'?'+urllib.parse.urlencode(dict(client_id='shipping-native',response_type='code',redirect_uri=self.redirect,scope='openid',state=self.state,nonce=self.nonce,code_challenge=b64(hashlib.sha256(self.verifier.encode()).digest()),code_challenge_method='S256'))
    def exchange(self,verifier=None):
        request=urllib.request.Request(self.discovery()['token_endpoint'],data=urllib.parse.urlencode(dict(grant_type='authorization_code',client_id='shipping-native',redirect_uri=self.redirect,code=self.code,code_verifier=verifier or self.verifier)).encode())
        with urllib.request.urlopen(request,context=self.context,timeout=10) as r:return json.load(r)
    def close(self):self.callback.shutdown();self.callback.server_close();self.thread.join()

class LoginForm(HTMLParser):
    def __init__(self):super().__init__();self.action=None
    def handle_starttag(self,tag,attrs):
        data=dict(attrs)
        if tag=='form' and data.get('id')=='kc-form-login':self.action=html.unescape(data['action'])

def synthetic_browser(flow,username,password):
    # Test-only HTTP user-agent: follows the real provider login form/cookies and
    # delivers the authorization response to the native loopback callback.
    # Production launches the system browser; the game never sees a password.
    jar=http.cookiejar.CookieJar()
    browser=urllib.request.build_opener(urllib.request.HTTPSHandler(context=flow.context),urllib.request.HTTPCookieProcessor(jar))
    with browser.open(flow.authorization_url(),timeout=15) as response:page=response.read().decode()
    form=LoginForm();form.feed(page)
    if not form.action or not form.action.startswith(flow.issuer+'/'):raise ValueError('login form unavailable')
    request=urllib.request.Request(form.action,data=urllib.parse.urlencode({'username':username,'password':password,'credentialId':''}).encode())
    try:
        with browser.open(request,timeout=15) as response:assert response.status==200
    except urllib.error.HTTPError:
        raise ValueError('Callback diagnostic: '+str(getattr(flow,'callback_diagnostic',{}))) from None
    if not flow.code:raise ValueError('no authorization response')
