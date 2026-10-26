import importlib.util
import pathlib
import subprocess
import tempfile
import unittest
spec=importlib.util.spec_from_file_location('audio_worker', pathlib.Path(__file__).parents[2]/'scripts/audio_worker.py')
worker=importlib.util.module_from_spec(spec); spec.loader.exec_module(worker)
class AudioWorkerTests(unittest.TestCase):
 def test_real_decode_duration_and_mime(self):
  with tempfile.TemporaryDirectory() as folder:
   for seconds, accepted in [(1,True),(31,False)]:
    path=f'{folder}/{seconds}.webm'
    subprocess.run(['ffmpeg','-v','error','-f','lavfi','-i','sine=frequency=440:sample_rate=16000','-t',str(seconds),'-c:a','libopus',path],check=True)
    self.assertEqual(worker.decoded_duration_ms(path) is not None,accepted)
    self.assertIsNone(worker.decoded_duration_ms(path,'audio/mp4'))
 def test_rejects_multiple_audio_tracks(self):
  with tempfile.TemporaryDirectory() as folder:
   path=f'{folder}/multiple.webm'
   subprocess.run(['ffmpeg','-v','error','-f','lavfi','-i','sine=frequency=440:sample_rate=16000','-f','lavfi','-i','sine=frequency=880:sample_rate=16000','-map','0:a','-map','1:a','-t','1','-c:a','libopus',path],check=True)
   self.assertIsNone(worker.decoded_duration_ms(path))
 def test_cleanup_orders_object_before_metadata_and_retries_failure(self):
  class Client:
   def __init__(self,fail=False): self.calls=[];self.fail=fail
   def rpc(self,name,payload=None):
    self.calls.append(name)
    return [{'id':'id','path':'path','expires_at':'2000-01-01T00:00:00+00:00','state':'verified'}] if name=='audio_worker_jobs' else None
   def call(self,*args):
    self.calls.append('storage_delete')
    if self.fail: raise TimeoutError()
  c=Client();self.assertEqual(worker.run_once(c)['expired'],1);self.assertEqual(c.calls,['audio_worker_jobs','storage_delete','finish_audio_expiration'])
  c=Client(True);self.assertEqual(worker.run_once(c)['retry'],1);self.assertNotIn('finish_audio_expiration',c.calls)
if __name__=='__main__':unittest.main()
