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