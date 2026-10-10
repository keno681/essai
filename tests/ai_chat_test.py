"""Exercise Godot HTTP against a local fake Responses API, without credentials or charges."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import subprocess
import threading
import time

requests = []

class FakeAPI(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def do_POST(self):
        payload = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        requests.append(payload)
        index = len(requests)
        assert self.path == '/v1/responses'
        assert self.headers['Authorization'] == 'Bearer sk-local-test-not-real'
        if index >= 5:
            time.sleep(0.5)
        code = {2: 401, 3: 429}.get(index, 200)
        body = {'output': [{'type': 'message', 'content': [{'type': 'output_text', 'text': 'La galaxie a bon goût !'}]}]}
        if index == 4:
            body = {'output': 'invalid'}
        encoded = json.dumps(body).encode()
        try:
            self.send_response(code)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(encoded)))
            self.end_headers()
            self.wfile.write(encoded)
        except (BrokenPipeError, ConnectionResetError):
            pass

server = ThreadingHTTPServer(('127.0.0.1', 0), FakeAPI)
threading.Thread(target=server.serve_forever, daemon=True).start()
env = os.environ.copy()
env.update(COSMO_TEST_PORT=str(server.server_port), XDG_DATA_HOME='/tmp/cosmo-ai-test', XDG_CONFIG_HOME='/tmp/cosmo-config', XDG_CACHE_HOME='/tmp/cosmo-cache')
try:
    result = subprocess.run(['godot', '--headless', '--audio-driver', 'Dummy', '--path', '.', '--script', 'tests/ai_chat_test.gd'], cwd=Path(__file__).resolve().parents[1], env=env, timeout=25)
    assert result.returncode == 0, result.returncode
    assert len(requests) == 6, len(requests)
    for payload in requests:
        assert payload['model'] == 'gpt-4.1-mini'
        assert payload['store'] is False
        assert payload['max_output_tokens'] == 160
        assert 1 <= len(payload['input']) <= 8
        assert 'commande actuelle' in payload['instructions']
    assert len(requests[1]['input']) == 3
    print('PASS API : six requêtes simulées, historique borné, contexte du client et budget de sortie.')
finally:
    server.shutdown()
    server.server_close()
