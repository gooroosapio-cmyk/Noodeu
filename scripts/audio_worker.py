#!/usr/bin/env python3
"""Worker explicite, jamais activé par cette livraison.
Une itération: python3 scripts/audio_worker.py --once
Env fournie par le propriétaire au futur hébergement: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY.
Ne journalise ni réponses, ni URL signée, ni clés. ffmpeg/ffprobe requis.
"""
import argparse
import datetime as dt
import json
import os
import subprocess
import tempfile
import urllib.request
import urllib.error

MAX_BYTES = 1048576
MAX_SAMPLES = 30 * 16000

def decoded_duration_ms(path, mime="audio/webm"):
    """Décode au plus 31s mono PCM16, la longueur réelle impose la limite, même sans Duration WebM."""
    probe = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'stream=codec_type:format=format_name', '-of', 'json', path], capture_output=True, timeout=10, check=True)
    info = json.loads(probe.stdout)
    streams = info.get('streams', [])
    formats = info.get('format', {}).get('format_name', '').split(',')
    expected = {'audio/webm':'webm', 'audio/mp4':'mp4', 'audio/ogg':'ogg'}
    if expected.get(mime) not in formats:
        return None
    if not streams or any(s.get('codec_type') != 'audio' for s in streams):
        return None
    decoded = subprocess.run(['ffmpeg', '-nostdin', '-v', 'error', '-i', path, '-t', '31', '-f', 's16le', '-ac', '1', '-ar', '16000', 'pipe:1'], capture_output=True, timeout=20, check=True)
    samples = len(decoded.stdout) // 2
    if not 0 < samples <= MAX_SAMPLES:
        return None
    return max(1, (samples * 1000 + 15999) // 16000)

class Client:
    def __init__(self):
        self.base = os.environ['SUPABASE_URL'].rstrip('/')
        self.key = os.environ['SUPABASE_SERVICE_ROLE_KEY']
        if not self.base.startswith('https://'):
            raise ValueError('HTTPS requis')
    def call(self, path, payload=None, method=None, binary=False):
        req = urllib.request.Request(self.base + path, data=None if payload is None else json.dumps(payload).encode(),
            headers={'Authorization': 'Bearer ' + self.key, 'apikey': self.key, 'Content-Type': 'application/json'}, method=method)
        with urllib.request.urlopen(req, timeout=30) as response:
            data = response.read(MAX_BYTES+1 if binary else 10485760)
        return data if binary else json.loads(data or b'null')
    def rpc(self, name, payload=None):
        return self.call('/rest/v1/rpc/' + name, payload or {}, 'POST')

def run_once(client, now=None):
    now = now or dt.datetime.now(dt.timezone.utc)
    counts = {'verified':0, 'rejected':0, 'expired':0, 'retry':0}
    for job in client.rpc('audio_worker_jobs'):
        try:
            if dt.datetime.fromisoformat(job['expires_at']) <= now:
                # API Storage supprime les octets ET sa ligne ; métadonnées ensuite, après succès uniquement.
                client.call('/storage/v1/object/answer-audio', {'prefixes':[job['path']]}, 'DELETE')
                client.rpc('finish_audio_expiration', {'p_id':job['id']})
                counts['expired'] += 1
            elif job['state'] == 'pending':
                try:
                    data = client.call('/storage/v1/object/answer-audio/' + job['path'], binary=True)
                except urllib.error.HTTPError as exc:
                    # Une réservation peut précéder l'upload. Ne pas la rejeter pendant ce délai.
                    if exc.code in (400,404): counts['retry'] += 1; continue
                    raise
                duration = None
                if 0 < len(data) <= MAX_BYTES:
                    with tempfile.TemporaryDirectory(prefix='noodeu-audio-') as folder:
                        filename = os.path.join(folder,'answer')
                        with open(filename,'wb') as output: output.write(data)
                        try: duration = decoded_duration_ms(filename, job['mime'])
                        except (subprocess.SubprocessError, ValueError): pass
                client.rpc('verify_answer_audio', {'p_id':job['id'], 'p_duration_ms':duration})
                counts['verified' if duration else 'rejected'] += 1
        except (urllib.error.URLError, TimeoutError, ValueError):
            counts['retry'] += 1
    return counts

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--once', action='store_true', required=True)
    parser.parse_args()
    print(json.dumps(run_once(Client())))
