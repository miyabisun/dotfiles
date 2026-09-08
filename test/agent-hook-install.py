#!/usr/bin/env python3
"""Exercise registered hooks from a real fresh/repeated bin/install."""
import json
import os
from pathlib import Path
import subprocess
import shutil
import socket
import threading
import tempfile
import tomllib

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as temp:
    home = Path(temp) / 'space home'
    home.mkdir()
    env = dict(os.environ, HOME=str(home), PATH='/usr/bin:/bin', MOCA_URL='')
    for key in ('HERDR_PANE_ID', 'HERDR_WORKSPACE_ID', 'TURN_END_EMITTER', 'CODEX_NOTIFY_EMITTER', 'CODEX_THREAD_ID'):
        env.pop(key, None)

    def install():
        subprocess.run(['/bin/bash', str(repo / 'bin/install')], env=env,
                       stdout=subprocess.DEVNULL, check=True)

    def launch_hooks():
        for relative in ('.codex/hooks.json', '.claude/settings.json', '.grok/hooks/lifecycle.json'):
            path = home / relative
            data = json.loads(path.read_text())
            for event, groups in data['hooks'].items():
                for group in groups:
                    for hook in group['hooks']:
                        payload = {'hook_event_name': event, 'reason': 'end_turn',
                                   'message': 'permission request',
                                   'tool_input': {'command': 'git reset --hard'}}
                        result = subprocess.run(['sh', '-c', hook['command']], input=json.dumps(payload),
                                                text=True, capture_output=True, env=env,
                                                cwd=path.parent, timeout=15)
                        assert result.returncode == 0, (relative, event, result.stderr)
                        if event == 'PreToolUse' and 'block-git-discard' in hook['command']:
                            assert json.loads(result.stdout)['hookSpecificOutput']['permissionDecision'] == 'deny'
        config = tomllib.loads((home / '.codex/config.toml').read_text())
        subprocess.run([str(home / '.local/bin' / config['notify'][0]),
                        json.dumps({'type': 'agent-turn-complete'})], env=env, check=True, timeout=15)
        for runtime in ('codex', 'grok'):
            config = tomllib.loads((home / f'.{runtime}/config.toml').read_text())
            assert not {'agent_talk', 'agent-talk'} & config.get('mcp_servers', {}).keys()

    install()
    launch_hooks()

    # Existing local settings must lose only the retired registrations.
    for runtime, name in (('codex', 'agent_talk'), ('grok', 'agent-talk')):
        path = home / f'.{runtime}/config.toml'
        with path.open('a') as file:
            file.write(f'\n[mcp_servers.{name}]\ncommand = "missing-peer"\n')
            file.write(f'[mcp_servers.{name}.env]\nTOKEN = "retired"\n')
            file.write('[mcp_servers.custom]\ncommand = "custom-mcp"\n')
            file.write('[machine_local]\nauth = "keep"\n')
            if runtime == 'codex':
                for event in ('pre_tool_use', 'post_tool_use', 'session_start'):
                    key = f'{home}/.codex/hooks.json:{event}:0:0'
                    file.write(f'[hooks.state.{json.dumps(key)}]\ntrusted_hash = "{event}"\n')
        path.chmod(0o600)
    path = home / '.claude/settings.json'
    data = json.loads(path.read_text())
    data['hooks']['SessionStart'][0]['hooks'].append({'type': 'command', 'command': 'true'})
    data['machine_local'] = {'auth': 'keep'}
    path.write_text(json.dumps(data))
    path.chmod(0o600)
    expected_claude = json.loads(json.dumps(data))
    install()
    launch_hooks()
    assert json.loads(path.read_text()) == expected_claude
    assert path.stat().st_mode & 0o777 == 0o600
    for runtime in ('codex', 'grok'):
        path = home / f'.{runtime}/config.toml'
        config = tomllib.loads(path.read_text())
        assert config['machine_local']['auth'] == 'keep'
        assert config['mcp_servers']['custom']['command'] == 'custom-mcp'
        assert path.stat().st_mode & 0o777 == 0o600
        if runtime == 'codex':
            state = config['hooks']['state']
            assert len(state) == 3
            for event in ('pre_tool_use', 'post_tool_use', 'session_start'):
                assert state[f'{home}/.codex/hooks.json:{event}:0:0']['trusted_hash'] == event
    snapshots = {p: p.read_bytes() for p in (home / '.codex/config.toml', home / '.grok/config.toml', home / '.claude/settings.json')}
    install()
    assert all(p.read_bytes() == content for p, content in snapshots.items())
    # Use the actual Herdr integration installer, not a fabricated hook fixture.
    herdr = shutil.which('herdr')
    assert herdr, 'Herdr must be installed to verify its distributed integration'
    tool_bin = Path(temp) / 'tools'
    tool_bin.mkdir()
    (tool_bin / 'herdr').symlink_to(herdr)
    env['PATH'] = f'{tool_bin}:/usr/bin:/bin'
    install()
    assert all(p.read_bytes() == content for p, content in snapshots.items())
    for agent in ('codex', 'claude'):
        reporter = home / f'.local/bin/herdr-{agent}-agent-state.sh'
        assert reporter.is_file() and not reporter.is_symlink()
        assert os.access(reporter, os.X_OK)

    # The official scripts report real startup/resume identity to an isolated
    # Unix socket. No request reaches the user's live Herdr server.
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as server:
        socket_path = str(Path(temp) / 'herdr.sock')
        server.bind(socket_path)
        server.listen()
        server.settimeout(5)
        env.update(HERDR_ENV='1', HERDR_SOCKET_PATH=socket_path, HERDR_PANE_ID='test:p1')
        for source in ('startup', 'resume'):
            if source == 'resume':
                install()
            for agent, relative in (('codex', '.codex/hooks.json'), ('claude', '.claude/settings.json')):
                command = json.loads((home / relative).read_text())['hooks']['SessionStart'][0]['hooks'][0]['command']
                requests = []

                def receive():
                    with server.accept()[0] as client:
                        client.settimeout(2)
                        request = json.loads(client.makefile().readline())
                        requests.append(request)
                        client.sendall(b'{"ok":true}\n')

                listener = threading.Thread(target=receive)
                listener.start()
                payload = {'hook_event_name': 'SessionStart', 'session_id': 'test-session',
                           'transcript_path': str(home / 'transcript.jsonl'), 'source': source}
                subprocess.run(['sh', '-c', command], input=json.dumps(payload), text=True,
                               env=env, check=True, timeout=10)
                listener.join(timeout=6)
                assert len(requests) == 1, (agent, source, requests)
                request = requests[0]
                assert request['method'] == 'pane.report_agent_session'
                params = request['params']
                assert params['pane_id'] == 'test:p1'
                assert params['agent'] == agent
                assert params['agent_session_id'] == 'test-session'
                assert params['session_start_source'] == source
                if agent == 'claude':
                    assert params['agent_session_path'] == payload['transcript_path']
    install()
    assert all(p.read_bytes() == content for p, content in snapshots.items())

    # A present but failing Herdr, or one producing no script, must fail install
    # even when a previously distributed reporter would otherwise hide it.
    (tool_bin / 'herdr').unlink()
    for exit_code in (1, 0):
        (tool_bin / 'herdr').write_text(f'#!/bin/sh\nexit {exit_code}\n')
        (tool_bin / 'herdr').chmod(0o755)
        result = subprocess.run(['/bin/bash', str(repo / 'bin/install')], env=env,
                                stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        assert result.returncode != 0, f'installer accepted absent generated scripts (exit {exit_code})'
print('agent hook real install/start/resume/reinstall and failure propagation: pass')
