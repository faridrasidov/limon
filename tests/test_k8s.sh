#!/usr/bin/env bash
# Kubernetes badge: pure-bash kubeconfig reading, namespace, danger contexts.
# SPDX-License-Identifier: GPL-3.0-or-later

# Options below are read by limon.sh once sourced.
# shellcheck disable=SC2034,SC2154

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/helpers.sh"
use_temp_home
load_limon
_limon_init_symbols

KDIR="$HOME/kube"
mkdir -p "$KDIR" "$HOME/bin"

# A stand-in kubectl that records every call, so tests can prove the prompt
# path never forks it for a kubeconfig the pure-bash reader understands.
KUBECTL_LOG="$HOME/kubectl.log"
cat > "$HOME/bin/kubectl" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "$KUBECTL_LOG"
case "\$*" in
    "config current-context") echo "from-kubectl" ;;
    "config view --minify -o jsonpath={..namespace}") echo "kubectl-ns" ;;
esac
EOF
chmod +x "$HOME/bin/kubectl"
PATH="$HOME/bin:$PATH"

# label — compute the badge from scratch, bypassing the 2s cache.
label() {
    unset __LIMON_K8S_CACHE_SEC
    _limon_k8s_label
    printf '%s' "$__LIMON_K8S_LABEL"
}

# As written by kubectl / kind: list items at column 0, long inline certs.
cert="$(printf 'A%.0s' {1..4000})"
cat > "$KDIR/kind" <<EOF
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: $cert
    server: https://127.0.0.1:6443
  name: kind-dev
contexts:
- context:
    cluster: kind-dev
    user: kind-dev
  name: kind-dev
- context:
    cluster: kind-dev
    namespace: awx
    user: kind-dev
  name: kind-awx
current-context: kind-awx
kind: Config
preferences: {}
users:
- name: kind-dev
  user:
    client-certificate-data: $cert
EOF

LIMON_K8S=1
export KUBECONFIG="$KDIR/kind"

# --- reading kubeconfig ---

it "reads the current context without kubectl"
rm -f "$KUBECTL_LOG"
assert_eq "(k8s:kind-awx)" "$(label)"

it "never forks kubectl for a block-style kubeconfig"
assert_eq "no" "$([[ -e "$KUBECTL_LOG" ]] && echo yes || echo no)"

it "adds the context's namespace when k8s_ns=1"
LIMON_K8S_NS=1
assert_eq "(k8s:kind-awx/awx)" "$(label)"

it "falls back to the default namespace when the context sets none"
sed -i 's/^current-context: .*/current-context: kind-dev/' "$KDIR/kind"
assert_eq "(k8s:kind-dev/default)" "$(label)"

it "shows nothing when k8s=0"
LIMON_K8S=0
assert_eq "" "$(label)"
LIMON_K8S=1

# Hand-written: name before context, 4-space indent, quotes, CRLF, comments.
printf '%s\r\n' \
    '# hand edited' \
    'contexts:' \
    '  - name: "prod-eks"' \
    '    context:' \
    '        cluster: prod' \
    "        namespace: 'payments'" \
    'current-context: "prod-eks"' > "$KDIR/hand"

it "handles name-first entries, quotes, deeper indents and CRLF"
KUBECONFIG="$KDIR/hand"
assert_eq "(k8s:prod-eks/payments)" "$(label)"

# minikube nests an extensions list with its own name: keys inside a context.
cat > "$KDIR/minikube" <<'EOF'
contexts:
- context:
    cluster: minikube
    extensions:
    - extension:
        provider: minikube.sigs.k8s.io
        namespace: not-this-one
      name: context_info
    namespace: kube-system
    user: minikube
  name: minikube
current-context: minikube
EOF

it "ignores nested names and namespaces inside context extensions"
KUBECONFIG="$KDIR/minikube"
assert_eq "(k8s:minikube/kube-system)" "$(label)"

# --- KUBECONFIG merging ---

cat > "$KDIR/empty-current" <<'EOF'
contexts:
- context:
    cluster: minikube
    namespace: shadowed-first
  name: minikube
current-context: ""
EOF

it "takes current-context from the first file that sets it"
KUBECONFIG="$KDIR/empty-current:$KDIR/missing:$KDIR/minikube"
assert_eq "(k8s:minikube/shadowed-first)" "$(label)"

it "skips missing files in KUBECONFIG"
KUBECONFIG="$KDIR/missing:$KDIR/hand"
assert_eq "(k8s:prod-eks/payments)" "$(label)"

it "shows nothing when no current context is set"
KUBECONFIG="$KDIR/empty-current"
rm -f "$KUBECTL_LOG"
assert_eq "" "$(label)"

it "does not fall back to kubectl when the context is simply unset"
assert_eq "no" "$([[ -e "$KUBECTL_LOG" ]] && echo yes || echo no)"

it "uses ~/.kube/config when KUBECONFIG is unset or empty"
mkdir -p "$HOME/.kube"
cp "$KDIR/minikube" "$HOME/.kube/config"
KUBECONFIG=""
assert_eq "(k8s:minikube/kube-system)" "$(label)"

# --- kubectl fallback ---

echo '{"apiVersion":"v1","current-context":"json-ctx"}' > "$KDIR/json"

it "falls back to kubectl for a JSON kubeconfig"
KUBECONFIG="$KDIR/json"
rm -f "$KUBECTL_LOG"
assert_eq "(k8s:from-kubectl/kubectl-ns)" "$(label)"

it "asks kubectl for the namespace only when k8s_ns=1"
LIMON_K8S_NS=0
rm -f "$KUBECTL_LOG"
label >/dev/null
assert_eq "config current-context" "$(cat "$KUBECTL_LOG")"
LIMON_K8S_NS=1

# --- kube-ps1 and caching ---

it "prefers KUBE_PS1_CONTEXT and KUBE_PS1_NAMESPACE when kube-ps1 is loaded"
KUBECONFIG="$KDIR/minikube"
KUBE_PS1_CONTEXT="from-kube-ps1" KUBE_PS1_NAMESPACE="ns1"
assert_eq "(k8s:from-kube-ps1/ns1)" "$(label)"
unset KUBE_PS1_CONTEXT KUBE_PS1_NAMESPACE

it "serves the cached context for 2s"
unset __LIMON_K8S_CACHE_SEC
_limon_k8s_label
KUBECONFIG="$KDIR/hand"
_limon_k8s_label
assert_eq "(k8s:minikube/kube-system)" "$__LIMON_K8S_LABEL"

# --- danger contexts ---

KUBECONFIG="$KDIR/hand"

it "flags a context matching a k8s_danger glob"
LIMON_K8S_DANGER='*prod*'
assert_eq "(⚠ k8s:prod-eks/payments)" "$(label)"

it "sets __LIMON_K8S_DANGER for a matching context"
unset __LIMON_K8S_CACHE_SEC
_limon_k8s_label
assert_eq "1" "$__LIMON_K8S_DANGER"

it "matches any of several comma-separated patterns, ignoring case"
LIMON_K8S_DANGER='staging,*-EKS'
assert_eq "(⚠ k8s:prod-eks/payments)" "$(label)"

it "uses the ASCII warning symbol when ascii=1"
LIMON_ASCII=1 _limon_init_symbols
assert_eq "(! k8s:prod-eks/payments)" "$(label)"
LIMON_ASCII=0 _limon_init_symbols

it "leaves non-matching contexts unflagged"
LIMON_K8S_DANGER='*-prd,staging'
assert_eq "(k8s:prod-eks/payments)" "$(label)"

it "does not expand danger patterns against files in the working directory"
mkdir -p "$HOME/globdir" && touch "$HOME/globdir/staging"
LIMON_K8S_DANGER='*'
assert_eq "(⚠ k8s:prod-eks/payments)" "$( cd "$HOME/globdir" && label )"

it "colors a danger badge with col_err in the safety prefix"
unset __LIMON_K8S_CACHE_SEC
_limon_safety_prefix '\[\e[0m\]' '\[\e[38;5;196m\]'
assert_contains "$__LIMON_SAFETY" '\[\e[38;5;196m\]('

it "keeps the safety prefix's \\[ \\] markers balanced"
assert_ok _limon_brackets_balanced "$__LIMON_SAFETY"
LIMON_K8S_DANGER=""

# --- config ---

limon_cmd() {
    env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" TERM=xterm-256color \
        bash "$LIMON_REPO_ROOT/limon.sh" "$@" 2>&1
}

it "defaults k8s_ns off and k8s_danger empty"
rm -f "$LIMON_CONF"
_limon_load_config
assert_eq "0:" "$LIMON_K8S_NS:$LIMON_K8S_DANGER"

it "round-trips k8s_ns and k8s_danger through the config file"
LIMON_K8S_NS=1 LIMON_K8S_DANGER='*prod*,*-prd'
mapfile -t flags < <(_limon_conf_flags)
_limon_write_config default "${flags[@]}"
LIMON_K8S_NS=0 LIMON_K8S_DANGER=""
_limon_load_config
assert_eq "1:*prod*,*-prd" "$LIMON_K8S_NS:$LIMON_K8S_DANGER"

it "accepts limon config k8s_ns=1"
rm -f "$LIMON_CONF"
limon_cmd config k8s_ns=1 >/dev/null
assert_contains "$(cat "$LIMON_CONF")" "-k8s_ns=1"

it "rejects k8s_ns=2"
assert_contains "$(limon_cmd config k8s_ns=2)" "k8s_ns must be 0 or 1"

it "accepts limon config k8s_danger with globs"
limon_cmd config 'k8s_danger=*prod*,*-prd' >/dev/null
assert_contains "$(cat "$LIMON_CONF")" "-k8s_danger=*prod*,*-prd"

it "rejects k8s_danger containing whitespace"
assert_contains "$(limon_cmd config 'k8s_danger=prod eks')" "without spaces"

it "clears k8s_danger with an empty value"
limon_cmd config 'k8s_danger=' >/dev/null
assert_not_contains "$(cat "$LIMON_CONF")" "k8s_danger"

finish
