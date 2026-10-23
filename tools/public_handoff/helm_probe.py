"""Actual saved-input thrusters and authoritative motion feedback over DTLS."""
import argparse
import json
import time
from peer_probe import PeerProof
from probe import CHECKS, check, free_port


def exercise(proof, rendered):
    port = free_port(udp=True)
    server = proof.peer_worker('server', port)
    client = proof.peer_worker('client', port, rendered=rendered)
    nonce = proof.until(client, lambda s: bool(s['nonce']))['nonce']
    proof.worker_call(client, {'op': 'ticket', 'ticket': proof.authority.issue_ticket(proof.account, 'server-a', nonce)})
    proof.until(client, lambda s: s.get('presentation', {}).get('ready'))
    for axis in [1, -1]:
        proof.worker_call(client, {'op': 'thruster', 'axis': axis})
        state = proof.until(server, lambda s: s['ships'][0]['lateral'] == axis and s['ships'][0]['side_speed'] * axis < -.01)
        check(state['ships'][0]['throttle'] == 0, 'saved sideways input moves hull in requested direction at neutral')
    proof.worker_call(client, {'op': 'menu', 'open': True})
    proof.until(server, lambda s: s['ships'][0]['lateral'] == 0)
    check(True, 'menu clears held lateral command on server')
    proof.worker_call(client, {'op': 'thruster', 'axis': 0})
    proof.worker_call(client, {'op': 'menu', 'open': False})
    time.sleep(.2)
    proof.worker_call(client, {'op': 'thruster', 'axis': 1})
    proof.until(server, lambda s: s['ships'][0]['lateral'] == 1)
    proof.worker_call(client, {'op': 'focus_loss'})
    proof.until(server, lambda s: s['ships'][0]['lateral'] == 0)
    check(True, 'window focus loss clears server thruster intent')
    proof.worker_call(client, {'op': 'input_off'})
    proof.rejected(server, client, {'op': 'helm', 'sequence': 10000, 'throttle': 0, 'lateral': 2})
    for sequence in range(10001, 10006):
        proof.worker_call(client, {'op': 'helm', 'sequence': sequence, 'throttle': 0, 'lateral': 1})
        time.sleep(.12)
    proof.until(server, lambda s: s['ships'][0]['lateral'] == 1)
    proof.until(server, lambda s: s['ships'][0]['lateral'] == 0)
    check(True, 'missing input timeout clears lateral intent')
    # Sustained reverse commands prove signed feedback comes from server velocity.
    for sequence in range(10006, 10036):
        proof.worker_call(client, {'op': 'helm', 'sequence': sequence, 'throttle': -.5})
        time.sleep(.1)
    reverse = proof.until(client, lambda s: s['snapshot'].get('forward_speed', 0) < -.05 and 'Reverse' in s['presentation']['indicator'])
    check(reverse['snapshot']['speed'] >= abs(reverse['snapshot']['forward_speed']) - .001, 'signed forward speed agrees with total server speed')
    proof.worker_call(client, {'op': 'helm', 'sequence': 10036, 'throttle': 0})
    coast = proof.until(client, lambda s: 'Coasting' in s['presentation']['indicator'])
    check(coast['presentation']['indicator_value'] == 0, 'neutral indicator distinguishes moving hull from stopped')
    if rendered:
        proof.worker_call(client, {'op': 'capture'})
        check((client['folder'] / 'helm.png').exists(), 'rendered HUD captured for inspection')
    proof.worker_call(client, {'op': 'disconnect'})
    proof.until(server, lambda s: s['members'] == 0)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--runtime', choices=['editor', 'release'], default='editor')
    parser.add_argument('--rendered', action='store_true')
    args = parser.parse_args()
    proof = PeerProof(args.runtime)
    try:
        proof.setup()
        exercise(proof, args.rendered)
        (proof.run / 'helm-summary.json').write_text(json.dumps({'passed': True, 'checks': CHECKS, 'runtime': args.runtime}, indent=2))
        print('PUBLIC_HELM_PASS', len(CHECKS), proof.run, flush=True)
    finally:
        proof.close()
