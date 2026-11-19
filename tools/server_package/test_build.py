"""Synthetic package safety checks. python -m unittest discover -s tools/server_package"""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location("server_build", Path(__file__).with_name("build.py"))
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)


class PackageChecks(unittest.TestCase):
    def test_contract_and_manifest(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            export = root / 'export'
            export.mkdir()
            for name in ('ShippingLanesServer.exe', 'ShippingLanesServer.pck', 'sqlite.dll'):
                (export / name).write_bytes(b'synthetic-runtime')
            output = root / build.ASSET
            build.package(export, output, 'v3.0.0')
            with zipfile.ZipFile(output) as archive:
                names = archive.namelist()
                self.assertIn('Bootstrap.ps1', names)
                self.assertEqual(json.loads(archive.read('current.json')), {'version': 'v3.0.0'})
                self.assertEqual(json.loads(archive.read('server-config.json'))['public_address'], '')
                manifest = json.loads(archive.read('versions/v3.0.0/package.json'))
                for name, digest in manifest['files'].items():
                    self.assertEqual(build.hashlib.sha256(archive.read('versions/v3.0.0/' + name)).hexdigest(), digest)
                self.assertFalse(any('saves/' in name or name.endswith('.db') for name in names))
            (export / 'world.json').write_text('private operator data')
            with self.assertRaises(ValueError):
                build.package(export, output, 'v3.0.1')

    def test_incomplete_export_and_bad_tag(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for version in ('v3.0.0', '../bad', 'v3.0.0-beta'):
                with self.assertRaises(ValueError):
                    build.package(root, root / 'output.zip', version)


if __name__ == '__main__':
    unittest.main()
