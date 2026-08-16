from server import APIHandler, CONFIG, load_json, save_json, CACHE, RATE_LIMITER, request_json, build_playlist_item, build_video_item, validate_playlist_id
import json
import io
from urllib.parse import urlparse, parse_qs
from datetime import datetime
import uuid
import time
import re

def application(environ, start_response):
    request_method = environ.get('REQUEST_METHOD', 'GET')
    path = environ.get('PATH_INFO', '/')
    query_string = environ.get('QUERY_STRING', '')
    if query_string:
        path += '?' + query_string

    # Create a minimal handler instance
    client_ip = environ.get('REMOTE_ADDR', '127.0.0.1')
    origin = environ.get('HTTP_ORIGIN', '')

    allowed, remaining = RATE_LIMITER.check(client_ip)
    rate_headers = {}
    reset_at = int(time.time()) + RATE_LIMITER.window
    rate_headers = RATE_LIMITER.get_headers(remaining, reset_at)

    if not allowed:
        response_data = {'success': False, 'error': {'code': 'RATE_LIMITED', 'message': 'Rate limit exceeded'}}
        response_body = json.dumps(response_data, ensure_ascii=False).encode('utf-8')
        headers = [
            ('Content-Type', 'application/json'),
            ('Content-Length', str(len(response_body))),
        ]
        for k, v in rate_headers.items():
            headers.append((k, v))
        start_response('429 Too Many Requests', headers)
        return [response_body]

    try:
        if request_method == 'OPTIONS':
            headers = list(rate_headers.items()) + [
                ('Access-Control-Allow-Origin', origin if origin in CONFIG['ALLOWED_ORIGINS'] else ''),
                ('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS'),
                ('Access-Control-Allow-Headers', 'Content-Type, Authorization'),
            ]
            start_response('204 No Content', headers)
            return [b'']

        parsed = urlparse(path)
        clean_path = parsed.path

        if clean_path == '/api/health':
            data = {'success': True, 'data': {'status': 'ok', 'timestamp': datetime.now().isoformat()}}
            status = 200
        elif clean_path == '/api/version':
            data = {'success': True, 'data': {'version': CONFIG['APP_VERSION'], 'environment': CONFIG['APP_ENV'], 'timestamp': datetime.now().isoformat()}}
            status = 200
        elif clean_path == '/api/youtube/playlists':
            if not CONFIG['YOUTUBE_API_KEY']:
                data = {'success': False, 'error': {'code': 'YOUTUBE_KEY_MISSING', 'message': 'YouTube API key not configured'}}
                status = 500
            else:
                cache_key = 'youtube:playlists'
                cached = CACHE.get(cache_key)
                if cached is not None:
                    data = {'success': True, 'data': cached}
                    status = 200
                else:
                    playlists = []
                    for playlist_id in CONFIG['PLAYLIST_IDS']:
                        url = f'https://www.googleapis.com/youtube/v3/playlists?key={CONFIG["YOUTUBE_API_KEY"]}&id={playlist_id}&maxResults=1&part=snippet,contentDetails'
                        try:
                            api_data = request_json(url)
                            for item in api_data.get('items', []):
                                playlists.append(build_playlist_item(item))
                        except Exception:
                            continue
                    if not playlists:
                        data = {'success': False, 'error': {'code': 'YOUTUBE_UNAVAILABLE', 'message': 'Não foi possível consultar o YouTube'}}
                        status = 502
                    else:
                        CACHE.set('youtube:playlists', playlists)
                        data = {'success': True, 'data': playlists}
                        status = 200
        elif clean_path.startswith('/api/youtube/playlist/'):
            playlist_id = clean_path.split('/')[-1]
            if not validate_playlist_id(playlist_id):
                data = {'success': False, 'error': {'code': 'INVALID_PLAYLIST_ID', 'message': 'ID de playlist inválido'}}
                status = 400
            elif not CONFIG['YOUTUBE_API_KEY']:
                data = {'success': False, 'error': {'code': 'YOUTUBE_KEY_MISSING', 'message': 'YouTube API key not configured'}}
                status = 500
            else:
                cache_key = f'youtube:playlist:{playlist_id}'
                cached = CACHE.get(cache_key)
                if cached is not None:
                    data = {'success': True, 'data': cached}
                    status = 200
                else:
                    url = f'https://www.googleapis.com/youtube/v3/playlistItems?key={CONFIG["YOUTUBE_API_KEY"]}&playlistId={playlist_id}&maxResults=50&part=snippet,contentDetails'
                    try:
                        api_data = request_json(url)
                        videos = []
                        for item in api_data.get('items', []):
                            video = build_video_item(item)
                            if video['videoId']:
                                videos.append(video)
                        if not videos:
                            data = {'success': False, 'error': {'code': 'YOUTUBE_UNAVAILABLE', 'message': 'Não foi possível carregar itens da playlist'}}
                            status = 502
                        else:
                            CACHE.set(cache_key, videos)
                            data = {'success': True, 'data': videos}
                            status = 200
                    except Exception:
                        data = {'success': False, 'error': {'code': 'YOUTUBE_UNAVAILABLE', 'message': 'Não foi possível carregar itens da playlist'}}
                        status = 502
        elif clean_path == '/api/videos':
            from server import VIDEOS_FILE
            file_data = load_json(VIDEOS_FILE)
            data = {'success': True, 'data': file_data.get('videos', [])}
            status = 200
        elif clean_path == '/api/courses':
            from server import COURSES_FILE
            file_data = load_json(COURSES_FILE)
            data = {'success': True, 'data': file_data.get('playlists', [])}
            status = 200
        else:
            data = {'success': False, 'error': {'code': 'NOT_FOUND', 'message': 'Endpoint not found'}}
            status = 404

        response_body = json.dumps(data, ensure_ascii=False).encode('utf-8')
        headers = [
            ('Content-Type', 'application/json'),
            ('Content-Length', str(len(response_body))),
        ]
        if origin in CONFIG['ALLOWED_ORIGINS']:
            headers.append(('Access-Control-Allow-Origin', origin))
            headers.append(('Vary', 'Origin'))
        for k, v in rate_headers.items():
            headers.append((k, v))

        start_response(f'{status} Status', headers)
        return [response_body]

    except Exception as e:
        response_body = json.dumps({'success': False, 'error': {'code': 'INTERNAL_ERROR', 'message': str(e)}}, ensure_ascii=False).encode('utf-8')
        start_response('500 Internal Server Error', [('Content-Type', 'application/json'), ('Content-Length', str(len(response_body)))])
        return [response_body]
