"""Test-only loopback UDP relay; opaque DTLS datagrams, bounded delayed queue."""
import heapq,random,select,socket,threading,time
class Impairment:
    def __init__(self, target, seed=7341):
        self.target=('127.0.0.1',target);self.client=None
        self.socket=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);self.socket.bind(('127.0.0.1',0))
        self.port=self.socket.getsockname()[1];self.random=random.Random(seed)
        self.lock=threading.Lock();self.queue=[];self.running=True;self.mode='clear';self.serial=0
        self.last_delivered=[0,0];self.stats=dict(received=0,dropped=0,duplicated=0,reordered=0,forwarded=0,bytes_to_client=0,bytes_to_server=0,max_udp_payload=0,max_queued=0)
        self.error=None
        self.thread=threading.Thread(target=self.guard,daemon=True);self.thread.start()
    def configure(self,mode):
        assert mode in ('clear','impaired','blackout')
        with self.lock:
            self.mode=mode
            if mode=='blackout':self.queue.clear()
    def metrics(self):
        if self.error:raise RuntimeError("Impairment relay failed") from self.error
        with self.lock:return dict(self.stats)
    def guard(self):
        try:self.run()
        except Exception as error:self.error=error;self.running=False
    def run(self):
        while self.running:
            ready,_,_=select.select([self.socket],[],[],.002)
            with self.lock:
                if ready:
                    try:data,source=self.socket.recvfrom(65535)
                    except ConnectionResetError:continue # Expected ICMP after the owned client disconnects.
                    if source==self.target:
                        destination=self.client;direction=0
                    else:
                        if source[0]!='127.0.0.1':continue
                        if self.client is None:self.client=source
                        if source!=self.client:continue
                        destination=self.target;direction=1
                    if destination is None:continue
                    self.serial+=1;n=self.serial;self.stats['received']+=1
                    if self.mode=='blackout' or (self.mode=='impaired' and self.random.random()<.07):
                        self.stats['dropped']+=1;continue
                    if len(self.queue)>=512:self.stats['dropped']+=1;continue
                    delay=0 if self.mode=='clear' else self.random.uniform(.02,.10)+(.2 if n%11==0 else 0)
                    heapq.heappush(self.queue,(time.monotonic()+delay,n,direction,destination,data))
                    if self.mode=='impaired' and n%17==0 and len(self.queue)<512:
                        heapq.heappush(self.queue,(time.monotonic()+delay+.03,n,direction,destination,data));self.stats['duplicated']+=1
                    self.stats['max_queued']=max(self.stats['max_queued'],len(self.queue))
                now=time.monotonic()
                while self.queue and self.queue[0][0]<=now:
                    _,n,direction,destination,data=heapq.heappop(self.queue)
                    self.socket.sendto(data,destination)
                    self.stats['forwarded']+=1
                    self.stats['bytes_to_client' if direction==0 else 'bytes_to_server']+=len(data)
                    self.stats['max_udp_payload']=max(self.stats['max_udp_payload'],len(data))
                    if n<self.last_delivered[direction]:self.stats['reordered']+=1
                    self.last_delivered[direction]=max(self.last_delivered[direction],n)
    def close(self):
        self.running=False;self.thread.join(timeout=2);self.socket.close()
        if self.thread.is_alive():raise RuntimeError("Relay did not stop")
        if self.error:raise RuntimeError("Impairment relay failed") from self.error
