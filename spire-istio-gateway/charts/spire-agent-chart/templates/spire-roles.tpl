apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: spire-agent-role
rules:
  - apiGroups: [""]
    resources: ["nodes/proxy"]
    verbs: ["get", "watch", "list", "create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: spire-agent-binding
subjects:
  - kind: ServiceAccount
    name: spire-agent
    namespace: {{ .Values.namespace }}
roleRef:
  kind: ClusterRole
  name: spire-agent-role
  apiGroup: rbac.authorization.k8s.io

