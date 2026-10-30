import unittest
from release_cloud import matching_run, raw_signature, run
from unittest.mock import Mock

class ReleaseTests(unittest.TestCase):
    def test_reuses_native_or_manual_run_for_same_commit(self):
        runs = [{'id': 'native', 'attributes': {'sourceCommit': {'commitSha': 'abc'}}}]
        self.assertEqual(matching_run(runs, 'abc')['id'], 'native')
        self.assertIsNone(matching_run(runs, 'different'))

    def test_pending_unresolved_run_is_safe(self):
        self.assertIsNone(matching_run([{'attributes': {'sourceCommit': None}}], 'abc'))

    def test_native_trigger_overlap_fails_before_build_start(self):
        api = Mock()
        api.request.return_value = {'data': {'attributes': {'isEnabled': True, 'branchStartCondition': {'source': {}}}}}
        with self.assertRaisesRegex(RuntimeError, 'native push'):
            run(api, 'abc')
        self.assertEqual(api.request.call_count, 1)

    def test_changed_audience_fails_before_build_start(self):
        api = Mock()
        api.request.side_effect = [
            {'data': {'attributes': {'isEnabled': True}}},
            {'data': {'attributes': {'isInternalGroup': True}}}
        ]
        api.all.return_value = [{'id': 'unexpected-tester'}]
        with self.assertRaisesRegex(RuntimeError, 'audience changed'):
            run(api, 'abc')
        self.assertEqual(api.request.call_count, 2)

    def test_signature_sign_padding_and_fixed_width(self):
        r = b'\x00\x80' + b'\x01' * 31
        s = b'\x01'
        body = b'\x02' + bytes([len(r)]) + r + b'\x02\x01' + s
        raw = raw_signature(b'\x30' + bytes([len(body)]) + body)
        self.assertEqual(len(raw), 64)
        self.assertEqual(raw[:32], r[1:])
        self.assertEqual(raw[32:], bytes(31) + s)

if __name__ == '__main__':
    unittest.main()
