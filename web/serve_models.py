import os
from http.server import HTTPServer, SimpleHTTPRequestHandler

class CORSRequestHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        self.send_header('Accept-Ranges', 'bytes')
        SimpleHTTPRequestHandler.end_headers(self)

if __name__ == '__main__':
    # Cambiamos al directorio donde están los modelos para servirlos directamente en la raíz del puerto 8081
    os.chdir('/app/web/models')
    print("Serving models with CORS on port 8081...")
    HTTPServer(('0.0.0.0', 8081), CORSRequestHandler).serve_forever()
