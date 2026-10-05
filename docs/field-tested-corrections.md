# Field-tested corrections

Issues found while running the pilot on an existing EKS 1.36 cluster in us-east-2 (2026-10-04), and what fixed each one.

| Area | Issue found | What worked |
| --- | --- | --- |
| Cluster capacity | Three t3.small nodes (11 pods each) could not hold the platform | Added a managed node group of 2 x t3.large. On a cluster eksctl did not create, `eksctl create nodegroup` needs a config file with `vpc.id`, `vpc.securityGroup` (control-plane SG) and `vpc.subnets` (`infra/agents-nodegroup.yaml`) |
| Networking | VPC had only public subnets, none tagged for internal load balancers | Tagged the subnets `kubernetes.io/role/internal-elb=1`. The internal NLB and a non-public RDS instance both work there. Production should use private subnets with NAT |
| Install method | Solo.io EKS add-ons not published for Kubernetes 1.36; Marketplace Helm charts need a subscription | Installed the upstream open-source charts (agentgateway v1.6.0 from `cr.agentgateway.dev`, kagent from `ghcr.io`) and deleted kagent's demo agents |
| Bedrock identity | Bedrock call used the node IAM role | The first proxy pod predated the Pod Identity association. Restarted the proxy and confirmed `AWS_CONTAINER_CREDENTIALS_FULL_URI` in the new pod |
| Model choice | Newer models may be missing from agentgateway v1.6.0's Bedrock catalog | `us.anthropic.claude-sonnet-4-5-20250929-v1:0` works |
| agentregistry install | Chart 0.4.0 ignores `database.host` / `database.password` | Used `database.postgres.type: external` with `external.url`, the RDS password URL-encoded, passed in a values file. Did not pin `image.tag` |
| arctl CLI | Installed but not executable (`umask 077` in the shell); `arctl configure --url` does nothing | `umask 022` before installing. arctl targets `localhost:12121` by default, so a port-forward is enough |
| Naming | arctl rejects hyphens in agent names | Registry names and gateway paths use lowercase letters and digits: `ekstroubleshooter`, `platformoncall`. Kubernetes names keep hyphens |
| Discovery | Registry does not discover agents created with kubectl | Registered a record (`kind: Agent` with `title` and a keyword-rich `description`). Registry search matches that text |
| Agent scaffold | arctl's ADK scaffold differs from hand-written code | `arctl init agent platformoncall --framework adk --language python`. Registry MCP passed via `MCP_SERVERS_CONFIG`; generated `mcp_tools.py` kept as is; built with `docker buildx --platform linux/amd64` |
| Bedrock tools | Bedrock rejected the request: empty tool description | kagent's base image drops docstrings. `call_agent.__doc__` is set explicitly |
| Routing | The registry Deployment names the kagent Agent `platformoncall-latest-platformoncall` | Gateway route rewrites to `/api/a2a/kagent/platformoncall-latest-platformoncall`. `KAGENT_NAMESPACE` omitted from the Deployment env (kagent sets it) |
| CloudWatch add-on | New pod crashed: `ImportError: cannot import name 'LogData'` | Application Signals Auto monitor injected ADOT Python. Excluded the `kagent`, `agentgateway-system` and `agentregistry` namespaces (`infra/cw-addon-config.json`) and restarted |
| Caller identity | On-call ServiceAccount name | `platformoncall-latest-platformoncall`; allow rule `jwt.sub == 'system:serviceaccount:kagent:platformoncall-latest-platformoncall'` |
| A2A card | The card's `url` points at kagent-controller, and BYO agents show kagent's generated card | The On-call Agent calls specialists by gateway path built from the registry name, not from card URLs |

## Security checks from the run

| Test | Expected | Got |
| --- | --- | --- |
| No token to the Troubleshooter route | 401 | 401 |
| Valid token, wrong caller | 403 | 403 |
| No token to the On-call route | 401 | 401 |
| incident-intake -> On-call -> own token -> Troubleshooter | diagnosis | OOMKilled root cause |
