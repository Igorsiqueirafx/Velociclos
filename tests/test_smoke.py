import os, sys, threading, time, json, urllib.request, urllib.error

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, ROOT)

os.environ['PORT'] = os.environ.get('TEST_PORT', '31099')

import server

def start():
    threading.Thread(target=server.run, daemon=True).start()
    deadline = time.time() + 15
    while time.time() < deadline:
        try:
            urllib.request.urlopen('http://127.0.0.1:' + os.environ['PORT'] + '/api/health', timeout=1)
            return
        except urllib.error.HTTPError:
            return
        except Exception:
            time.sleep(0.25)
    raise RuntimeError('server did not become ready within 15s')

def call(method, path, token=None, body=None):
    url = 'http://127.0.0.1:' + os.environ['PORT'] + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    if token:
        req.add_header('Authorization', 'Bearer ' + token)
    try:
        with urllib.request.urlopen(req, timeout=5) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code
    except (urllib.error.URLError, ConnectionError):
        return 0

def main():
    start()
    checks = [
        ('GET /api/health', call('GET', '/api/health'), 200),
        ('GET /api/videos (public)', call('GET', '/api/videos'), 200),
        ('POST /api/videos no token', call('POST', '/api/videos', body={'title': 'x'}), 401),
        ('GET /admin/ no token', call('GET', '/admin/'), 401),
    ]
    ok = True
    for name, got, exp in checks:
        passed = got == exp
        ok = ok and passed
        print(('PASS' if passed else 'FAIL') + ': ' + name + ' -> ' + str(got) + ' (expected ' + str(exp) + ')')
    print('SMOKE TEST ' + ('OK' if ok else 'FAILED'))
    sys.exit(0 if ok else 1)

if __name__ == '__main__':
    main()
