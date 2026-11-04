"""Server render lokal: sajikan halaman model-viewer + GLB, terima hasil WebP."""
import base64
import http.server
import os
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
MODELS = sys.argv[1]
OUT = sys.argv[2]
os.makedirs(OUT, exist_ok=True)


class Handler(http.server.SimpleHTTPRequestHandler):
    def translate_path(self, path):
        path = path.split('?', 1)[0]
        if path.startswith('/models/'):
            return os.path.join(MODELS, os.path.basename(path))
        return os.path.join(ROOT, path.lstrip('/') or 'index.html')

    def do_POST(self):
        if not self.path.startswith('/save/'):
            self.send_error(404)
            return
        name = os.path.basename(self.path[len('/save/'):])
        length = int(self.headers.get('Content-Length', 0))
        data = self.rfile.read(length).decode()
        raw = base64.b64decode(data.split(',', 1)[1])
        with open(os.path.join(OUT, name), 'wb') as fh:
            fh.write(raw)
        self.send_response(200)
        self.end_headers()
        self.wfile.write(f'ok {len(raw)}'.encode())


http.server.ThreadingHTTPServer(('127.0.0.1', 8770), Handler).serve_forever()
