# Pilot logs

Terminal output from the pilot run on 2026-10-04 (EKS 1.36, us-east-2), in the order the steps happened. Failures are kept on purpose: each one maps to a fix in [../field-tested-corrections.md](../field-tested-corrections.md).

Account-specific values are masked: the AWS account ID is shown as `111122223333`, and security group, subnet and VPC IDs, the cluster's OIDC ID, the IAM policy ID and the RDS endpoint are replaced with placeholders.

| Log | Step | What it shows | Outcome |
| --- | --- | --- | --- |
| [01-nodegroup-and-security-groups.log](01-nodegroup-and-security-groups.log) | 1 | Adding a managed t3.large node group to a cluster eksctl did not create; security group rules between old and new nodes | Pass |
| [02-subnet-tags-and-lb-controller.log](02-subnet-tags-and-lb-controller.log) | 2 | Tagging subnets for internal load balancers; AWS Load Balancer Controller with Pod Identity | Pass |
| [03-kagent-install.log](03-kagent-install.log) | 3 | kagent 0.10.3 from the upstream Helm charts; demo agents removed; tool server and PostgreSQL volume | Pass |
| [04-bedrock-route-through-gateway.log](04-bedrock-route-through-gateway.log) | 5 | Bedrock answering through agentgateway with the proxy's Pod Identity role, from a laptop and from inside the cluster; kagent ModelConfig accepted | Pass |
| [05-agentregistry-install-on-rds.log](05-agentregistry-install-on-rds.log) | 6 | agentregistry v0.4.0 on RDS; arctl; the registry's MCP server answering in-cluster | Pass |
| [06-troubleshooter-a2a-through-gateway.log](06-troubleshooter-a2a-through-gateway.log) | 8 | EKS Troubleshooter diagnosing the OOMKilled demo workload over A2A through the gateway | Pass |
| [07-registry-schema-and-adk-scaffold.log](07-registry-schema-and-adk-scaffold.log) | 9 | agentregistry's Agent schema and the arctl ADK scaffold files | Reference |
| [08-oncall-first-run-empty-tool-description.log](08-oncall-first-run-empty-tool-description.log) | 9 | First On-call run: Bedrock rejects a tool with an empty description | Fail, fixed |
| [09-oncall-crash-otel-importerror.log](09-oncall-crash-otel-importerror.log) | 9 | On-call 0.1.1 crashing: CloudWatch Application Signals injected ADOT Python (`ImportError: LogData`) | Fail, fixed |
| [10-end-to-end-incident-success.log](10-end-to-end-incident-success.log) | 11 | Full flow: On-call discovers `ekstroubleshooter` in the registry, calls it, returns the root cause; gateway hops | Pass |
| [11-security-policies-and-tests.log](11-security-policies-and-tests.log) | 10 | JWT and caller allow-list policies; 401, 403, 401, then the authorized end-to-end run | Pass |

Logs 04, 05, 06 and 10 were captured from the session transcript, and long request bodies are abridged with `...`. The rest are the terminal output as saved.
