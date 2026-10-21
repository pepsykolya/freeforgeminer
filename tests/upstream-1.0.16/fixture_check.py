#!/usr/bin/env python3
"""FreeForgeMiner regression check against the official Common Foundry 1.0.16 fixture.

The fixture (mainnet-template-nonce0-count32.coefficients.bin) and its expected output
SHA-256 come from the Common Foundry 1.0.16 AMD HIP package (benchmarks/run_batch32_qualification.sh,
MIT, (c) 2026 Common Foundry AMD HIP contributors; see LICENSE-fixtures). The replay worker must
reproduce the 32 final activations of nonces 0..31 byte for byte, the same on every run, and its
GPU BLAKE3 digests (RUNBATCHDIGEST) must equal BLAKE3 of those activations.

usage: fixture_check.py WORKER MODEL-V2.bank [RUNS]
"""
import hashlib, os, struct, subprocess, sys, tempfile, time

EXPECTED = "fe67b80af4671210cd33306d0976c7dbb285dd55203d8eff733866cd7ef4a7a7"
HERE = os.path.dirname(os.path.abspath(__file__))
COEF = os.path.join(HERE, "mainnet-template-nonce0-count32.coefficients.bin")
BATCH = 32

def main():
    worker, model = sys.argv[1], sys.argv[2]
    runs = int(sys.argv[3]) if len(sys.argv) > 3 else 3
    try:
        import blake3
    except ImportError:
        blake3 = None
    out = tempfile.mkdtemp(prefix="ffm-fixture-")
    chal = os.path.join(out, "challenges.bin")
    challenges = [hashlib.sha256(b"ffm-fixture-%d" % i).digest() for i in range(BATCH)]
    open(chal, "wb").write(b"".join(challenges))
    p = subprocess.Popen([worker, "--server", model], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT, text=True, bufsize=1)
    def cmd(line):
        t = time.time()
        p.stdin.write(line + "\n"); p.stdin.flush()
        for text in p.stdout:
            if "CMFD_V4_REPLAY_DONE" in text:
                return time.time() - t
            if text.lower().startswith("error"):
                raise SystemExit("worker error: " + text.strip())
        raise SystemExit("worker exited")
    for text in p.stdout:
        if "READY" in text:
            break
    else:
        raise SystemExit("worker did not start")
    fail = 0
    for run in range(1, runs + 1):
        prefix = os.path.join(out, f"run{run}")
        secs = cmd(f"RUNBATCH\t{BATCH}\t{COEF}\t{prefix}")
        data = open(prefix + "-final-activation.bin", "rb").read()
        sha = hashlib.sha256(data).hexdigest()
        ok = sha == EXPECTED
        fail += not ok
        print(f"run {run}: sha256 {sha} {'OK' if ok else 'MISMATCH'} ({len(data)} bytes, {secs:.2f} s)")
    secs = cmd(f"RUNBATCHDIGEST\t{BATCH}\t{COEF}\t{os.path.join(out, 'dig')}\t{chal}")
    p.stdin.write("QUIT\n"); p.stdin.flush(); p.wait(timeout=60)
    if blake3 is not None:
        dig = open(os.path.join(out, "dig-final-digest.bin"), "rb").read()
        lane = len(data) // BATCH
        match = 0
        for i in range(BATCH):
            h = blake3.blake3(derive_key_context="CommonFoundry/ForgeMatrix/V4/FinalActivation/v1")
            h.update(challenges[i]); h.update(struct.pack("<Q", lane // 4)); h.update(data[i * lane:(i + 1) * lane])
            match += h.digest() == dig[i * 32:(i + 1) * 32]
        print(f"GPU digest: {match}/{BATCH} lanes equal BLAKE3 of the fixture output ({secs:.2f} s)")
        fail += match != BATCH
    else:
        print("GPU digest: skipped (pip install blake3)")
    print("FIXTURE PASS" if not fail else "FIXTURE FAIL")
    sys.exit(1 if fail else 0)

if __name__ == "__main__":
    main()
