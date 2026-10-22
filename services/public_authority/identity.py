"""Access-token validation against an operator-pinned issuer/audience/JWKS.

Unknown keys fail closed. Key rotation requires a refreshed operator configuration;
no token-supplied URLs are fetched. This boundary cannot create accounts or import
private saves. Account enrollment and browser UX are separate rollout work.
"""
import base64
import json
import math
import time
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import rsa, padding


def unique(pairs):
    value = {}
    for key, item in pairs:
        if key in value: raise ValueError('duplicate field')
        value[key] = item
    return value


def decode(value):
    return base64.b64decode(value + '=' * (-len(value) % 4), altchars=b'-_', validate=True)


def validate(token, config):
    if not isinstance(token, str) or not 0 < len(token) <= 32768: raise ValueError('token')
    header, payload, signature = token.split('.')
    head = json.loads(decode(header), object_pairs_hook=unique)
    claims = json.loads(decode(payload), object_pairs_hook=unique)
    if not isinstance(head, dict) or not isinstance(claims, dict): raise ValueError('object')
    if head.get('alg') != 'RS256' or head.get('crit'): raise ValueError('algorithm')
    keys = [key for key in config['jwks']['keys'] if key.get('kid') == head.get('kid') and key.get('kty') == 'RSA' and key.get('use') == 'sig' and key.get('alg') == 'RS256']
    if len(keys) != 1: raise ValueError('key')
    key = keys[0]
    public = rsa.RSAPublicNumbers(int.from_bytes(decode(key['e']), 'big'), int.from_bytes(decode(key['n']), 'big')).public_key()
    public.verify(decode(signature), (header + '.' + payload).encode('ascii'), padding.PKCS1v15(), hashes.SHA256())
    if claims.get('iss') != config['issuer']: raise ValueError('issuer')
    audience = claims.get('aud')
    if isinstance(audience, str): audience = [audience]
    if not isinstance(audience, list) or config['audience'] not in audience: raise ValueError('audience')
    now = time.time()
    for field in ('exp', 'iat', 'nbf'):
        if field not in claims and field != 'exp': continue
        number = claims.get(field)
        if type(number) not in (int, float) or not math.isfinite(number): raise ValueError('time')
    if claims['exp'] <= now or claims.get('nbf', 0) > now or claims.get('iat', 0) > now + 30: raise ValueError('time')
    if not isinstance(claims.get('sub'), str) or not 0 < len(claims['sub']) <= 256: raise ValueError('subject')
    return claims
