#!/usr/bin/env bash
# Reproducible FreeForgeMiner build: upstream Common Foundry at a pinned commit + patches/.
set -euo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
UPSTREAM=https://github.com/Common-Foundry-1/CommonFoundry.git
UPSTREAM_COMMIT=8e57bf0f06a4729821b40d0bc678e4788d4eef8f
CUTLASS_COMMIT=ad7b2f5e84fcfa124cb02b91d5bd26d238c0459e
NVCC="${NVCC:-/usr/local/cuda-12.9/bin/nvcc}"
WORK="${WORK:-$HERE/build}"
mkdir -p "$WORK" "$HERE/dist"

[ -d "$WORK/CommonFoundry" ] || git clone --filter=blob:none "$UPSTREAM" "$WORK/CommonFoundry"
git -C "$WORK/CommonFoundry" checkout -q --detach "$UPSTREAM_COMMIT"
git -C "$WORK/CommonFoundry" -c user.name=build -c user.email=build@local am -q "$HERE"/patches/*.patch

[ -d "$WORK/cutlass" ] || git clone -q --filter=blob:none --depth=1 --branch v3.9.2 https://github.com/NVIDIA/cutlass.git "$WORK/cutlass"
git -C "$WORK/cutlass" checkout -q --detach "$CUTLASS_COMMIT"

# GPU worker (one CUDA translation unit; CUDA runtime linked statically)
"$NVCC" -O3 -std=c++17   $(for a in 70 75 80 86 89 90 120; do printf -- "--generate-code=arch=compute_%s,code=sm_%s " $a $a; done)   --generate-code=arch=compute_70,code=compute_70   -I"$WORK/cutlass/include" \
  "$WORK/CommonFoundry/tools/production-v4-prover/cuda/koala_four_limb_replay.cu" \
  -o "$HERE/dist/cmfd-v4-replay"

# Pool miner
( cd "$WORK/CommonFoundry" && \
  CMFD_BUILD_SOURCE_COMMIT="$(git rev-parse HEAD)" \
  cargo build --release -p cmfd-miner --features production-mainnet )
cp "$WORK/CommonFoundry/target/release/cmfd-miner" "$HERE/dist/cmfd-miner"
echo "built: $HERE/dist/cmfd-miner $HERE/dist/cmfd-v4-replay"
