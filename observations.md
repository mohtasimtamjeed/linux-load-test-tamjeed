# System Load Observations & Production Architecture Analysis

### 1. Observations Under Load

During the chaos testing phase (`03_stress_and_populate.sh`), system behaviors under isolated and concurrent stress revealed key Linux kernel mechanics:

* **Disk Write Saturation (`tmpfs`):** Writing random data via `dd` filled the 256MB allocated boundary rapidly. Once saturated, writes failed cleanly with an `ENOSPC` (No space left on device) error. Because the filesystem was strictly capped at 256M, it did not consume host memory uncontrollably, safeguarding colocated system processes.
* **Memory & Swap Dynamics:** Squeezing 200MB of virtual memory using `stress-ng` visibly contracted available system buffers and cached memory in `free -h`. Because the load remained within system capacity limits, `dmesg | grep -i oom` returned empty, demonstrating that the kernel's Out-Of-Memory (OOM) killer did not need to terminate rogue processes.
* **Concurrent Stress (`--all`):** Combining multi-core CPU load, memory allocation, and disk saturation pushed CPU utilization near 100% and increased load averages. While responsiveness degraded temporarily, the system recovered to baseline immediately upon timeout completion without kernel panic or locked inodes.


### 2. Architectural Changes for a Real Production Server

If deploying this service architecture in an enterprise production environment, several modifications should be implemented:

1. **Containerized Resource Quotas (cgroups v2):** Rather than running ad-hoc user scripts directly on bare EC2 host namespaces, encapsulate the workload inside Docker or Kubernetes (K8s). Enforce explicit CPU and memory request/limit quotas via `cgroups` (e.g., `resources.limits.memory`) so runaway allocations are killed locally at the container boundary rather than impacting the host node.
2. **Centralized Log Aggregation:** While `logrotate` protects local storage, production logs must not remain siloed on ephemeral instances. Stream logs via FluentBit or AWS CloudWatch Logs Agent to centralized datastores (OpenSearch/Datadog/CloudWatch) with alerting triggers for fast diagnostics.
3. **Automated Horizontal Autoscaling:** Rather than relying on a static EC2 instance enduring CPU/memory saturation, front the service with an Application Load Balancer (ALB) and AWS Auto Scaling Group (ASG) based on target tracking metrics (e.g., 70% average CPU utilization).
4. **Managed Telemetry & Alarms:** Replace shell-based cron logging with structured metric collectors (Prometheus Node Exporter) linked to Grafana dashboards and PagerDuty alerts for immediate on-call notification when scratch disks exceed 85% capacity.
5. **Zero-Trust Network Perimeter:** Never expose custom SSH ports directly to the internet (even on port 2222). Restrict perimeter access using AWS Systems Manager (SSM) Session Manager or an authenticated WireGuard/Tailscale VPN mesh, removing open ingress ports from public security groups altogether.

