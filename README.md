# Linux Load Test Assignment - BongoDev

* **Student Nickname:** tamjeed
* **Service Account:** bgdsvc_tamjeed

## Overview

This repository contains automated infrastructure scripts, observations, and verification proofs for building, stress testing, securing, monitoring, and tearing down an isolated Linux service environment.

## Progress Checklist

- [x] **Part 1:** Service Identity (`01_create_user.sh`) - Idempotent system account setup
- [x] **Part 2:** Memory-backed Scratch Storage (`02_setup_tmpfs.sh`)
- [ ] **Part 3:** Stress Testing & Fault Injection (`03_stress_and_populate.sh`)
- [ ] **Part 4:** SSH Key-Based Access Configuration
- [ ] **Part 5:** SSH Hardening (Port 2222, Least Privilege)
- [ ] **Part 6:** Automated Telemetry & Maintenance (Cron)
- [ ] **Part 7:** Log Rotation Management (`logrotate`)
- [ ] **Part 8:** Orderly Teardown (`04_cleanup.sh`)


### Part 1: Service Identity (`01_create_user.sh`)

#### Purpose & DevOps Context

In production infrastructure, applications should never run under `root` or a personal interactive user account. Dedicated service accounts follow the **Principle of Least Privilege (PoLP)**, ensuring processes only possess permissions essential to their function.

#### Script Implementation Highlights

* **Idempotency Check:** Uses `id "$SVC_NAME" &>/dev/null` to inspect user existence before executing creation logic. If the account already exists, the script exits cleanly without throwing an exit code error, making it safe for repeated automation runs (e.g., CI/CD pipelines).
* **System Flag (`-r`):** Creates a system account with a low UID (< 1000), separating administrative service accounts from standard human users.
* **Home Directory (`-m`):** Provisions a dedicated home path (`/home/$SVC_NAME`) required for storing service-specific configurations like SSH keys.
* **No-Interactive Login Shell (`-s /usr/sbin/nologin`):** Blocks direct interactive shell sessions via SSH or TTY. If the service is compromised via remote execution, the attacker cannot spawn an interactive shell directly as this identity.
* **Verification:** Outputs user credentials and group assignments via `id` and `getent passwd` to validate successful provisioning.


### Part 2: Fast Scratch Space (`02_setup_tmpfs.sh`)

#### Purpose & DevOps Context

To handle high-throughput ephemeral caching workloads without introducing physical disk I/O bottlenecks, services use `tmpfs`—a virtual memory-backed filesystem. Setting a hard boundary (`size=256M`) is vital: an unconstrained `tmpfs` will continuously consume RAM as files are written, eventually triggering kernel Out-Of-Memory (OOM) interventions.

#### Script Implementation Highlights

* **Mount Verification & Idempotency:** Employs `mountpoint -q` to verify whether `/mnt/${SVC_NAME}_tmp` is already an active mount, avoiding redundant mount calls on repeated executions.
* **Strict Memory Capping:** Mounts using `-o size=256M` to strictly encapsulate memory allocation inside system RAM.
* **Access Boundary:** Reassigns path ownership to `$SVC_NAME:$SVC_NAME` via `chown`, ensuring the unprivileged service user can write files while preserving isolated directory permissions.
* **Storage Validation:** Runs `df -h` to verify mount point configuration and capacity constraints.



### Part 3: Chaos Engineering & Fault Injection (`03_stress_and_populate.sh`)

#### Purpose & DevOps Context

Validating system reliability under adverse conditions prevents unexpected production failures. By intentionally driving disk writes to capacity, loading multiple CPU cores, and allocating aggressive memory buffers, we verify kernel thresholds and metric behaviors under load.

#### Script Implementation Highlights

* **CLI Flag Parsing:** Incorporates a `case` dispatcher supporting `--cpu`, `--mem`, `--disk`, and `--all` modes.
* **Controlled Disk Saturation:** Writes pseudo-random binary data via `dd` until filesystem limits are met. Demonstrates safe write termination without kernel file corruption.
* **CPU & RAM Saturation:** Invokes `stress-ng` executing under the unprivileged service identity (`sudo -u "$SVC_NAME"`), constraining stress threads to dedicated resource budgets.
* **Telemetry Verification:** Captures transient memory utilization swings across `free -h` intervals and verifies through `dmesg | grep -i oom` whether the Linux kernel invoked the Out-Of-Memory Killer.


### Part 4: SSH Key-Based Access Configuration

#### Purpose & DevOps Context
Deploying public-key authentication eliminates credential transmission over networks and mitigates automated credential attacks. Setting the standard POSIX permission boundaries (`0700` for `.ssh` directories and `0600` for `authorized_keys`) ensures the daemon does not drop connections due to insecure access flags.

#### Implementation Highlights
* **Cryptographic Standard:** Generated an **ED25519** elliptic-curve key pair, offering smaller key footprint and improved resistance to side-channel attacks compared to traditional RSA keys.
* **Strict Permission Hardening:** Enforced `chmod 700` on `/home/$SVC_NAME/.ssh` and `chmod 600` on `/home/$SVC_NAME/.ssh/authorized_keys`, ensuring read/write isolation exclusively for the service user.
* **Defense-in-Depth Verification:** Attempting an SSH handshake authenticates the key pair while respecting the `/usr/sbin/nologin` restriction, terminating interactive shell invocation while validating cryptographic identity.


### Part 5: SSH Daemon Hardening (`sshd_config`)

#### Purpose & DevOps Context

Default SSH configurations listening on port 22 with password authentication enabled are vulnerable to credential stuffing and unauthorized root access. Hardening the daemon reduces the attack surface and enforces the Principle of Least Privilege across the host perimeter.

#### Implementation Highlights

* **Port Obfuscation (`Port 2222`):** Relocates the listening socket away from standard port 22, deflecting automated vulnerability scanners.
* **Root Login Prohibition (`PermitRootLogin no`):** Blocks direct targeting of the administrative superuser.
* **Cryptographic Enforcement (`PasswordAuthentication no`):** Disables interactive password prompts, mandating key-based cryptographic handshakes.
* **User Whitelisting (`AllowUsers`):** Explicitly whitelists authorized accounts (`bgdsvc_tamjeed`), automatically rejecting connection attempts from unlisted system identities.
* **Verification:** Validated via socket binding (`ss -tulpn`) and successful key handshake over port 2222.



### Part 6: Scheduled Automation with Cron

#### Purpose & DevOps Context

Manual server inspection is unscalable and error-prone. Implementing scheduled background tasks ensures continuous operational telemetry collection for post-incident diagnostics and automated garbage collection to prevent capacity exhaustion in ephemeral workspaces.

#### Implementation Highlights

* **Telemetry Collector (`bgdsvc_tamjeed_monitor.sh`):** Periodically samples system RAM status (`free -h`), scratch filesystem capacity (`df -h`), and active processes owned by the service identity (`ps -u`) into `/var/log/bgdsvc_tamjeed/monitor.log`.
* **Garbage Collection Pruner (`bgdsvc_tamjeed_cleanup_old_files.sh`):** Uses `find "$TMPDIR" -type f -mtime +1 -delete` to prune scratch files older than 24 hours.
* **Cron Scheduling:** Installed under the service user crontab (`crontab -u bgdsvc_tamjeed`):
  * `*/5 * * * *`: Runs telemetry collection every 5 minutes.
  * `0 2 * * *`: Executes scratch storage pruning nightly at 02:00 UTC.