# Contributing

Thanks for your interest in improving this EKS Agent Mesh pilot. This repository is a working reference for an incident-response agent mesh running on Amazon EKS, and contributions are welcome when they make the setup clearer, safer, or easier to reproduce.

## How to contribute

1. Fork the repository and create a topic branch for your change.
2. Keep changes focused and easy to review.
3. Update the relevant docs or scripts when changing behavior.
4. Run the smallest validation that matches the affected path before opening a pull request.
5. Open a pull request with a short explanation of the problem, the fix, and any validation performed.

## Repository structure

- `agents/` contains the agent implementations and related code.
- `infra/` contains EKS and IAM related configuration.
- `k8s/` contains Kubernetes manifests for routing, policies, and demo workloads.
- `registry/` contains agent registry records and deployment configuration.
- `scripts/` contains the end-to-end pilot steps in order.
- `docs/` contains diagrams, logs, and field-tested corrections.

## Development workflow

- Prefer small, reviewable changes.
- Keep manifests and scripts consistent with the current pilot flow.
- If you adjust a template or environment variable, update the matching example script or documentation.
- Do not commit secrets or environment-specific credentials.

## Validation

For infra and deployment changes, validate with the relevant script(s) in `scripts/` or with the smallest targeted test available in the repo. If you add a new component or change an existing one, document how to apply or verify it.

## Pull request checklist

- [ ] Clear description of the problem and solution
- [ ] Related docs or scripts updated
- [ ] No secrets or personal credentials included
- [ ] Validation run for changed behavior
- [ ] Backward-compatible or clearly documented for the existing pilot flow

## Code ownership

This repository is maintained by the project owner. Contact the repository owner before large or breaking changes.
