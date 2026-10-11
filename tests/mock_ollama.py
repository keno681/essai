"""One-shot local test server: no real model or external API used."""
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
class Handler(BaseHTTPRequestHandler):
    turns = 0
    def do_POST(self):
        assert self.path == '/api/chat'
        assert not self.headers.get('Authorization')
        payload=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        assert payload['model']=='qwen3:8b'
        assert payload['stream'] is False and payload['think'] is False
        assert 'fake-private-key' not in json.dumps(payload)
        assert len(payload['tools'])==5
        Handler.turns += 1
        if Handler.turns == 1:
            calls=[{'function':{'name':'read_file','index':0,'arguments':{'path':'ui.gd','start':1,'lines':20}}}]
        else:
            assistant=next(m for m in payload['messages'] if m.get('tool_calls'))
            for call in assistant['tool_calls']:
                assert 'index' not in call['function']
                assert 'id' not in call and 'type' not in call
            calls=[
               {'function':{'name':'replace_text','index':0,'arguments':{'path':'ui.gd','old':'edc478','new':'55cc77'}}},
               {'function':{'name':'finish','index':1,'arguments':{'explanation':'Cadre vert préparé localement'}}}]
        data=json.dumps({'message':{'role':'assistant','content':'','tool_calls':calls},'done':True,'done_reason':'stop'}).encode()
        self.send_response(200)
        self.send_header('Content-Type','application/json')
        self.send_header('Content-Length',str(len(data)))
        self.end_headers()
        self.wfile.write(data)
    def log_message(self,*args): pass
server=HTTPServer(('127.0.0.1',11434),Handler)
server.timeout=30
server.handle_request()
server.handle_request()
server.server_close()
print('MOCK OLLAMA HTTP PASSED')
