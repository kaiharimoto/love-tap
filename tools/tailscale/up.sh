#!/usr/bin/env bash
# tools/tailscale/up.sh — bring up the two nodes the reliability run needs.
#
#   TS_AUTHKEY=tskey-auth-… bash tools/tailscale/up.sh     # with a key
#   bash tools/tailscale/up.sh --login                     # without one: two URLs to click
#   bash tools/tailscale/up.sh --down
#
# Two userspace tailscaled daemons, one per phone, each with its own state directory and its own
# SOCKS port, so the host and the client are genuinely two nodes on a tailnet rather than two
# processes on loopback pretending. Userspace mode means no TUN device and no root networking,
# which is what makes this runnable here at all.
#
# The auth key is read from the environment and never written anywhere: not into a file, not into
# a log, not into the manifest. It is a secret with a short life and putting it on disk in a
# repository is a failure condition of this build. toolchain/ts/AUTHKEY_STATUS records only
# whether one has ever been supplied — the word `pending` or the word `supplied`, nothing else.
set -euo pipefail
cd "$(dirname "$0")/../.."

TS_DIR="toolchain/ts"
TAILSCALED="$TS_DIR/bin/tailscaled"
TAILSCALE="$TS_DIR/bin/tailscale"
NODES=(a b)
SOCKS_BASE=1055

down() {
  for n in "${NODES[@]}"; do
    # log out first, so the node stops showing as online in the admin console rather than
    # lingering there as a machine that never comes back
    [ -S "$TS_DIR/$n/tailscaled.sock" ] && \
      "$TAILSCALE" --socket="$TS_DIR/$n/tailscaled.sock" logout >/dev/null 2>&1 || true
    if [ -f "$TS_DIR/$n/pid" ]; then
      kill "$(cat "$TS_DIR/$n/pid")" 2>/dev/null || true
      rm -f "$TS_DIR/$n/pid"
    fi
  done
  echo "both nodes are down and logged out"
  echo "a key that was not marked ephemeral leaves lovetap-a and lovetap-b registered;"
  echo "remove them at login.tailscale.com/admin/machines, and revoke the key under Settings > Keys."
}

if [ "${1:-}" = "--down" ]; then down; exit 0; fi
LOGIN="no"
[ "${1:-}" = "--login" ] && LOGIN="yes"

[ -x "$TAILSCALED" ] || { echo "up.sh: $TAILSCALED is not there; run ./bootstrap.sh" >&2; exit 2; }

if [ -z "${TS_AUTHKEY:-}" ] && [ "$LOGIN" = "no" ]; then
  echo "pending" > "$TS_DIR/AUTHKEY_STATUS"
  cat >&2 <<'MSG'
up.sh: no TS_AUTHKEY in the environment.

  The two phones cannot join a tailnet without one, so the tailscale transport cannot be exercised
  end to end and evidence/reliability.json will record the tailscale run as pending rather than as
  passing. Everything else — the protocol, the pairing, the fault runs — is exercised over the
  local transport and is unaffected.

  Two ways to run it:

    TS_AUTHKEY=tskey-auth-… bash tools/tailscale/up.sh

      A key from the admin console — login.tailscale.com/admin/settings/keys, "Generate auth key".
      Not from the Tailscale app: the app is a client and has no key generation in it. Tick
      Reusable (there are two nodes), tick Ephemeral (they disappear when this container does),
      and set the shortest expiry offered. The key is read from the environment here and is never
      written to disk. Revoke it in the same place afterwards.

    bash tools/tailscale/up.sh --login

      No key at all. Each node prints a URL; open it, sign in, and it comes up. Two clicks instead
      of a credential, and nothing to revoke afterwards.
MSG
  exit 3
fi

if [ "$LOGIN" = "yes" ]; then echo "interactive" > "$TS_DIR/AUTHKEY_STATUS"
else echo "supplied" > "$TS_DIR/AUTHKEY_STATUS"; fi
down || true

i=0
for n in "${NODES[@]}"; do
  mkdir -p "$TS_DIR/$n"
  socks=$((SOCKS_BASE + i))
  # userspace networking: no TUN, no root, a SOCKS5 port per node to reach the tailnet through
  "$TAILSCALED" \
    --tun=userspace-networking \
    --socks5-server="127.0.0.1:$socks" \
    --outbound-http-proxy-listen="127.0.0.1:$((socks + 100))" \
    --statedir="$TS_DIR/$n/state" \
    --socket="$TS_DIR/$n/tailscaled.sock" \
    >"$TS_DIR/$n/tailscaled.log" 2>&1 &
  echo $! > "$TS_DIR/$n/pid"
  i=$((i + 1))
done

sleep 2
for n in "${NODES[@]}"; do
  if [ "$LOGIN" = "yes" ]; then
    # No key anywhere. tailscale prints a URL; open it, sign in, and the node comes up. Two clicks
    # instead of a credential, which is the better trade if you would rather not hand one over at
    # all: nothing reusable ever exists, and there is nothing to revoke afterwards.
    echo "· node $n wants approving; open this and sign in:"
    "$TAILSCALE" --socket="$TS_DIR/$n/tailscaled.sock" up \
        --hostname="lovetap-$n" --accept-routes=false --accept-dns=false --timeout=300s \
      2>&1 | tee "$TS_DIR/$n/up.log" | grep -E "https://" || true
  else
    # --authkey comes from the environment, on the command line of this process only
    "$TAILSCALE" --socket="$TS_DIR/$n/tailscaled.sock" up \
        --authkey="$TS_AUTHKEY" \
        --hostname="lovetap-$n" \
        --accept-routes=false \
        --accept-dns=false \
        >"$TS_DIR/$n/up.log" 2>&1 \
      || { echo "up.sh: node $n would not come up; see $TS_DIR/$n/up.log" >&2; exit 4; }
  fi
  ip=$("$TAILSCALE" --socket="$TS_DIR/$n/tailscaled.sock" ip -4 | head -1)
  echo "$ip" > "$TS_DIR/$n/address"
  echo "node $n is up at $ip"
done

echo
echo "the host serves on $(cat "$TS_DIR/a/address"), the client reaches it there and nowhere else."
