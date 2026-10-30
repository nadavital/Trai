"""Exact-branch bridge. Apple handles signing and Nadav-only distribution."""
import base64
import json
import os
import subprocess
import tempfile
import time
import urllib.request

BASE = 'https://api.appstoreconnect.apple.com/v1'
WORKFLOW = 'E6027AED-8478-4754-AF01-867A8F3B837C'
REFERENCE = 'a5a694ef-2c78-4ffd-bb2e-933d8a5446a7'
GROUP = 'f0a703ac-4101-4f65-8a62-872a7b56a2f4'
TESTER = '35e9861d-3db2-46db-a835-d6c7387e343e'
BRANCH = 'release/trai-49-cloud'


def b64(value):
    return base64.urlsafe_b64encode(value).rstrip(b'=').decode()


def raw_signature(der):
    # ECDSA P-256 DER sequence consists of two short INTEGERs.
    if der[0] != 48 or der[2] != 2:
        raise ValueError('Invalid ECDSA signature')
    size = der[3]
    r = int.from_bytes(der[4:4 + size], 'big')
    pos = 4 + size
    if der[pos] != 2:
        raise ValueError('Invalid ECDSA signature')
    size = der[pos + 1]
    s = int.from_bytes(der[pos + 2:pos + 2 + size], 'big')
    return r.to_bytes(32, 'big') + s.to_bytes(32, 'big')


def matching_run(runs, sha):
    return next((r for r in runs if (r['attributes'].get('sourceCommit') or {}).get('commitSha') == sha), None)


class Apple:
    def __init__(self, key):
        self.key = key

    def request(self, path, body=None):
        now = int(time.time())
        header = b64(json.dumps({'alg': 'ES256', 'kid': os.environ['ASC_KEY_ID'], 'typ': 'JWT'}).encode())
        claims = b64(json.dumps({'iss': os.environ['ASC_ISSUER_ID'], 'iat': now, 'exp': now + 300, 'aud': 'appstoreconnect-v1'}).encode())
        message = (header + '.' + claims).encode()
        result = subprocess.run(['openssl', 'dgst', '-sha256', '-sign', self.key], input=message, capture_output=True, check=True)
        token = message.decode() + '.' + b64(raw_signature(result.stdout))
        url = path if path.startswith(BASE + '/') else BASE + path
        if not url.startswith(BASE + '/'):
            raise RuntimeError('Unexpected API host')
        req = urllib.request.Request(url, data=json.dumps(body).encode() if body else None,
            headers={'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'})
        # Never retry POST: ambiguous transport failure must be reconciled by SHA.
        with urllib.request.urlopen(req, timeout=45) as response:
            return json.load(response)

    def all(self, path):
        items = []
        while path:
            response = self.request(path)
            items.extend(response['data'])
            path = response.get('links', {}).get('next')
        return items


def run(api, sha):
    workflow = api.request('/ciWorkflows/' + WORKFLOW)['data']['attributes']
    if not workflow['isEnabled'] or workflow.get('branchStartCondition'):
        raise RuntimeError('Require enabled workflow with native push trigger removed to avoid overlap')
    testers = api.all('/betaGroups/' + GROUP + '/betaTesters?limit=200')
    group = api.request('/betaGroups/' + GROUP)['data']['attributes']
    if not group['isInternalGroup'] or {t['id'] for t in testers} != {TESTER}:
        raise RuntimeError('Internal audience changed; refusing release')
    runs = api.all('/ciWorkflows/' + WORKFLOW + '/buildRuns?limit=200')
    current = matching_run(runs, sha)
    if not current:
        # Ref builds resolve latest HEAD. Skip obsolete queued pushes rather than release the wrong commit.
        req = urllib.request.Request('https://api.github.com/repos/nadavital/Trai/git/ref/heads/' + BRANCH,
                                     headers={'Accept': 'application/vnd.github+json'})
        with urllib.request.urlopen(req, timeout=30) as response:
            head = json.load(response)['object']['sha']
        if head != sha:
            print('Superseded push; latest commit owns release.')
            return
        current = api.request('/ciBuildRuns', {'data': {'type': 'ciBuildRuns', 'relationships': {
            'workflow': {'data': {'type': 'ciWorkflows', 'id': WORKFLOW}},
            'sourceBranchOrTag': {'data': {'type': 'scmGitReferences', 'id': REFERENCE}}
        }}})['data']
        print('Started Apple cloud run:', current['id'], flush=True)
    else:
        print('Reusing existing run for commit:', current['id'], flush=True)
    deadline = time.monotonic() + 2100
    while time.monotonic() < deadline:
        current = api.request('/ciBuildRuns/' + current['id'])['data']
        attrs = current['attributes']
        actual = (attrs.get('sourceCommit') or {}).get('commitSha')
        if actual and actual != sha:
            raise RuntimeError('Cloud source differs from push; inspect run before retry')
        print('Cloud:', attrs.get('number'), attrs['executionProgress'], attrs.get('completionStatus'), flush=True)
        if attrs['executionProgress'] == 'COMPLETE':
            if attrs.get('completionStatus') != 'SUCCEEDED':
                raise RuntimeError('Apple cloud release failed')
            builds = api.all('/ciBuildRuns/' + current['id'] + '/builds')
            for build in builds:
                detail = api.request('/builds/' + build['id'] + '/buildBetaDetail')['data']['attributes']
                groups = api.all('/builds/' + build['id'] + '/betaGroups?limit=200')
                if build['attributes']['processingState'] == 'VALID' and detail['internalBuildState'] == 'IN_BETA_TESTING' and {g['id'] for g in groups} == {GROUP}:
                    print('Verified Nadav-only TestFlight build:', build['attributes']['version'], 'commit:', sha)
                    return
        time.sleep(30)
    raise RuntimeError('Timed out; reconcile existing run, do not blindly start another')


def main():
    if os.environ.get('GITHUB_REPOSITORY') != 'nadavital/Trai' or os.environ.get('GITHUB_REF') != 'refs/heads/' + BRANCH or os.environ.get('GITHUB_EVENT_NAME') != 'push':
        raise RuntimeError('Release requires the approved repository branch push')
    # Key is environment-scoped, never an argument or repository file.
    with tempfile.TemporaryDirectory(prefix='trai-asc-') as folder:
        path = os.path.join(folder, 'key.p8')
        with open(os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), 'w') as stream:
            stream.write(os.environ.pop('ASC_PRIVATE_KEY'))
        run(Apple(path), os.environ['GITHUB_SHA'])


if __name__ == '__main__':
    main()
