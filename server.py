import json
import os
import urllib.parse
import urllib.request
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import uuid
from datetime import datetime

def load_env_file(path):
    if not os.path.exists(path):
        return
    with open(path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            if '=' in line:
                key, value = line.split('=', 1)
                os.environ.setdefault(key.strip(), value.strip())

load_env_file(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '.env'))

CONFIG = {
    'PORT': 3001,
    'ADMIN_PASSWORD': 'velociclos2024',
    'DATA_DIR': os.path.dirname(os.path.abspath(__file__)),
    'YOUTUBE_API_KEY': os.environ.get('YOUTUBE_API_KEY', ''),
    'PLAYLIST_IDS': [
        'PLWhqc48nlRWLhDr-YqQhwVGhCFwUCcw7I',
        'PLWhqc48nlRWIBLg85_VDOcqRAq-BWi-J9',
        'PLWhqc48nlRWKnmtTenj21hAdK3Lasx-Yh',
        'PLWhqc48nlRWJKFtMeqiQjWAtGRitoYSFK',
        'PLWhqc48nlRWL8F5Tl7UtqY2S4SXlYG6B5',
        'PLWhqc48nlRWJ-8YQA16dpId_6L1w4ySKV',
        'PLWhqc48nlRWKWGyAfGr0iLpwtsGexhnaZ',
        'PLWhqc48nlRWJpjKnjSaJpq4jMRE_ukg6V',
        'PLWhqc48nlRWJZyYdEi3gcSIHx6cy0Hxlb',
        'PLWhqc48nlRWITJy0wfqGdXprKLkEecXIv',
        'PLWhqc48nlRWLqE-RBi_RTBjKit-xFWeOC',
        'PLWhqc48nlRWLahmd1buhzix23XcAFJkqD',
        'PLWhqc48nlRWKu17t5xqL6Sr3T6Pwn1DcL',
        'PLWhqc48nlRWIKhZTuRMMy4vtOhN_HANlw',
        'PLWhqc48nlRWIuwZkiaLAfDfFKWWndWUxO',
    ]
}

VIDEOS_FILE = os.path.join(CONFIG['DATA_DIR'], 'data', 'videos.json')
COURSES_FILE = os.path.join(CONFIG['DATA_DIR'], 'data', 'courses.json')

os.makedirs(os.path.dirname(VIDEOS_FILE), exist_ok=True)

for file_path in [VIDEOS_FILE, COURSES_FILE]:
    if not os.path.exists(file_path):
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump({'videos': [] if 'videos' in file_path else {'playlists': []}}, f, indent=2, ensure_ascii=False)

def load_json(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        return json.load(f)

def save_json(file_path, data):
    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

class APIHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if path == '/api/videos':
            data = load_json(VIDEOS_FILE)
            self.send_json(data.get('videos', []))
            return

        if path == '/api/courses':
            data = load_json(COURSES_FILE)
            self.send_json(data.get('playlists', []))
            return

        if path == '/api/health':
            self.send_json({'status': 'ok', 'timestamp': datetime.now().isoformat()})
            return

        if path.startswith('/api/youtube/playlists'):
            return self.handle_youtube_playlists()

        if path.startswith('/api/youtube/playlist/'):
            playlist_id = path.split('/')[-1]
            return self.handle_youtube_playlist_items(playlist_id)

        if path.startswith('/admin/'):
            self.path = '/admin/index.html'
            super().do_GET()
            return

        self.send_error(404)

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if path == '/api/videos':
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            data = json.loads(body.decode('utf-8'))

            videos = load_json(VIDEOS_FILE)
            new_video = {
                'id': str(uuid.uuid4()),
                'videoId': data.get('videoId', ''),
                'title': data.get('title', ''),
                'description': data.get('description', ''),
                'module': data.get('module', ''),
                'createdAt': datetime.now().isoformat()
            }
            videos['videos'].append(new_video)
            save_json(VIDEOS_FILE, videos)
            self.send_json(new_video, status=201)
            return

        if path == '/api/courses/sync':
            return self.handle_youtube_sync()

        self.send_error(404)

    def do_PUT(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if path.startswith('/api/videos/'):
            video_id = path.split('/')[-1]
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            data = json.loads(body.decode('utf-8'))

            videos = load_json(VIDEOS_FILE)
            index = next((i for i, v in enumerate(videos['videos']) if v['id'] == video_id), None)

            if index is None:
                self.send_error(404, 'Video not found')
                return

            videos['videos'][index].update(data)
            videos['videos'][index]['id'] = video_id
            save_json(VIDEOS_FILE, videos)
            self.send_json(videos['videos'][index])
            return

        self.send_error(404)

    def do_DELETE(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if path.startswith('/api/videos/'):
            video_id = path.split('/')[-1]
            videos = load_json(VIDEOS_FILE)
            videos['videos'] = [v for v in videos['videos'] if v['id'] != video_id]
            save_json(VIDEOS_FILE, videos)
            self.send_response(204)
            self.end_headers()
            return

        self.send_error(404)

    def handle_youtube_playlists(self):
        if not CONFIG['YOUTUBE_API_KEY']:
            self.send_json({'error': 'YouTube API key not configured'}, status=500)
            return

        try:
            playlists = []
            for playlist_id in CONFIG['PLAYLIST_IDS']:
                url = f'https://www.googleapis.com/youtube/v3/playlists?key={CONFIG["YOUTUBE_API_KEY"]}&id={playlist_id}&maxResults=1&part=snippet,contentDetails'
                try:
                    with urllib.request.urlopen(url) as resp:
                        data = json.loads(resp.read().decode('utf-8'))
                        for item in data.get('items', []):
                            snippet = item.get('snippet', {})
                            content_details = item.get('contentDetails', {})
                            playlists.append({
                                'id': item['id'],
                                'title': snippet.get('title', 'Sem título'),
                                'description': snippet.get('description', ''),
                                'thumbnail': snippet.get('thumbnails', {}).get('medium', {}).get('url', ''),
                                'videoCount': content_details.get('itemCount', 0)
                            })
                except Exception:
                    continue
            self.send_json(playlists)
        except Exception as e:
            self.send_json({'error': str(e)}, status=500)

    def handle_youtube_playlist_items(self, playlist_id):
        if not CONFIG['YOUTUBE_API_KEY']:
            self.send_json({'error': 'YouTube API key not configured'}, status=500)
            return

        try:
            url = f'https://www.googleapis.com/youtube/v3/playlistItems?key={CONFIG["YOUTUBE_API_KEY"]}&playlistId={playlist_id}&maxResults=50&part=snippet,contentDetails'
            with urllib.request.urlopen(url) as resp:
                data = json.loads(resp.read().decode('utf-8'))
                videos = []
                for item in data.get('items', []):
                    snippet = item.get('snippet', {})
                    content_details = item.get('contentDetails', {})
                    videos.append({
                        'videoId': content_details.get('videoId', ''),
                        'title': snippet.get('title', 'Sem título'),
                        'description': snippet.get('description', ''),
                        'thumbnail': snippet.get('thumbnails', {}).get('medium', {}).get('url', '')
                    })
                self.send_json(videos)
        except Exception as e:
            self.send_json({'error': str(e)}, status=500)

    def handle_youtube_sync(self):
        if not CONFIG['YOUTUBE_API_KEY']:
            self.send_json({'error': 'YouTube API key not configured'}, status=500)
            return

        try:
            playlists = []
            for playlist_id in CONFIG['PLAYLIST_IDS']:
                url = f'https://www.googleapis.com/youtube/v3/playlists?key={CONFIG["YOUTUBE_API_KEY"]}&id={playlist_id}&maxResults=1&part=snippet,contentDetails'
                print(f'SYNC URL: {url}')
                try:
                    with urllib.request.urlopen(url) as resp:
                        raw = resp.read().decode('utf-8')
                        print(f'SYNC RESP for {playlist_id}: {raw[:200]}')
                        data = json.loads(raw)
                        for item in data.get('items', []):
                            snippet = item.get('snippet', {})
                            content_details = item.get('contentDetails', {})
                            playlists.append({
                                'id': item['id'],
                                'title': snippet.get('title', 'Sem título'),
                                'description': snippet.get('description', ''),
                                'thumbnail': snippet.get('thumbnails', {}).get('medium', {}).get('url', ''),
                                'videoCount': content_details.get('itemCount', 0)
                            })
                except Exception as e:
                    print(f'SYNC ERROR for {playlist_id}: {e}')
                    continue

            courses = load_json(COURSES_FILE)
            courses['playlists'] = playlists
            save_json(COURSES_FILE, courses)
            self.send_json({'synced': len(playlists), 'playlists': playlists})
        except Exception as e:
            self.send_json({'error': str(e)}, status=500)

    def send_json(self, data, status=200):
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
        self.end_headers()
        self.wfile.write(json.dumps(data, ensure_ascii=False).encode('utf-8'))

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
        self.end_headers()

def run():
    server = HTTPServer(('0.0.0.0', CONFIG['PORT']), APIHandler)
    print(f'Velociclos API running on http://localhost:{CONFIG["PORT"]}')
    print(f'Admin panel: http://localhost:{CONFIG["PORT"]}/admin/index.html')
    print(f'Password: {CONFIG["ADMIN_PASSWORD"]}')
    server.serve_forever()

if __name__ == '__main__':
    run()
