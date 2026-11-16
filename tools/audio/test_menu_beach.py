"""Validate committed PCM, loop joins and reproducible baking."""
from array import array
from pathlib import Path
import hashlib
import subprocess
import sys
import unittest
import wave

ROOT = Path(__file__).resolve().parents[2]


class BeachAudioTest(unittest.TestCase):
    def test_bake_and_loop_seams(self):
        paths = sorted((ROOT / 'features/audio').glob('menu_*.wav'))
        before = [hashlib.sha256(p.read_bytes()).hexdigest() for p in paths]
        subprocess.run([sys.executable, str(ROOT / 'tools/audio/generate_menu_beach.py')], check=True)
        self.assertEqual(before, [hashlib.sha256(p.read_bytes()).hexdigest() for p in paths])
        self.assertEqual(len(paths), 2)
        for path in paths:
            with wave.open(str(path)) as wav:
                self.assertEqual((wav.getnchannels(), wav.getsampwidth(), wav.getframerate(), wav.getnframes()), (2, 2, 22050, 32 * 22050))
                samples = array('h', wav.readframes(wav.getnframes()))
            if sys.byteorder != 'little': samples.byteswap()
            self.assertLess(max(abs(v) for v in samples), 30000)
            self.assertGreater(max(abs(v) for v in samples), 100)
            for channel in range(2):
                values = samples[channel::2]
                # Join no larger than ordinary adjacent samples (no seam click).
                join = abs(values[-1] - values[0])
                self.assertLessEqual(join, max(abs(b-a) for a,b in zip(values, values[1:])))
                if 'gulls' in path.name:
                    self.assertTrue(all(v == 0 for v in values[:22050]))
                    self.assertTrue(all(v == 0 for v in values[-22050:]))


if __name__ == '__main__':
    unittest.main()
