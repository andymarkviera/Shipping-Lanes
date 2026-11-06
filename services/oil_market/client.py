"""Trusted public-server HTTPS client; no local simulation or uncertain replay IDs."""
import http.client
import json
import ssl
from urllib.parse import urlsplit
from .settlement import OPERATIONS


class PublicClient:
    operations = OPERATIONS
    mutations = ('oil_accept',)
    unavailable_code = 'MARKET_UNAVAILABLE'

    def __init__(self, endpoint, server, credential, cafile=None, timeout=5):
        url = urlsplit(endpoint)
        if url.scheme != 'https' or not url.hostname or url.username or url.password or url.query or url.fragment:
            raise ValueError('verified HTTPS authority endpoint required')
        self.url, self.server, self.credential = url, server, credential
        self.context = ssl.create_default_context(cafile=cafile)
        self.timeout = timeout

    def execute(self, request):
        if request.get('realm') != 'public' or request.get('op') not in self.operations:
            return dict(ok=False, code='BAD_REQUEST')
        connection = http.client.HTTPSConnection(self.url.hostname, self.url.port,
                                                context=self.context, timeout=self.timeout)
        try:
            connection.request('POST', self.url.path or '/v1/authority', json.dumps(request),
                               {'Authorization': 'Bearer ' + self.credential,
                                'X-Server-Id': self.server, 'Content-Type': 'application/json'})
            response = connection.getresponse()
            payload = response.read(65537)
            if response.status >= 500 or len(payload) > 65536:
                raise ValueError('unavailable')
            result = json.loads(payload)
            if type(result) is not dict or type(result.get('ok')) is not bool or type(result.get('code')) is not str:
                raise ValueError('invalid response')
            return result
        except (OSError, ValueError, http.client.HTTPException):
            # A failed response can follow a committed trade. Retain original
            # action_id/quote/revision and retry after rebind; never reprice here.
            return dict(ok=False, code=self.unavailable_code, uncertain=request['op'] in self.mutations)
        finally:
            connection.close()
