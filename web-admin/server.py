import http.server
import socketserver
import os

PORT = 8889
DIRECTORY = os.path.dirname(os.path.abspath(__file__))

class SPAHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def do_GET(self):
        path = self.translate_path(self.path)
        if not os.path.exists(path) or os.path.isdir(path):
            self.path = '/index.html'
        return super().do_GET()

with socketserver.TCPServer(("", PORT), SPAHandler) as httpd:
    print(f"Serving at port {PORT}")
    httpd.serve_forever()
