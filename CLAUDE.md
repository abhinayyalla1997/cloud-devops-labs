# CLAUDE.md

## 🧭 Purpose

This file defines strict operating rules for Claude when working in this repository.
Claude must follow these rules before making any code, infrastructure, or repository changes.

---

## 🚫 Mandatory Safety Rules

1. **No direct changes without approval**

   * Always explain the plan before making any changes.
   * Wait for explicit user approval before proceeding.

2. **No automatic Git operations**

   * Do NOT run `git commit`, `git push`, `git merge`, or create branches.
   * Only suggest commands — user will execute them.

3. **No deletion without confirmation**

   * Do NOT delete files, folders, or configurations unless explicitly approved.

4. **No restructuring without explanation**

   * Any folder/file movement must be explained first.

---

## 🧠 Architecture Awareness (Critical)

* Always refer to:

  * `DevSecOps_Project_Architecture.png`

* Ensure ALL implementations align with:

  * CI/CD flow (GitHub Actions)
  * Security stages (OWASP, Trivy, SonarQube, Checkov)
  * Container build & push (Docker → ECR)
  * Kubernetes deployment (kubeadm on EC2, NOT EKS)
  * Monitoring (Prometheus + Grafana)

* If any change conflicts with architecture:

  * STOP
  * Ask for clarification

---

## ⚙️ Infrastructure Rules

* Kubernetes cluster:

  * Must be **kubeadm-based on EC2**
  * Do NOT use EKS or managed Kubernetes

* Infrastructure provisioning:

  * Use **Terraform (primary)**
  * Use **Ansible only if necessary for configuration**

* Avoid:

  * Hardcoding values
  * Manual steps if automation is possible

---

## 🔐 DevSecOps Requirements

Ensure pipeline always includes:

* Dependency scanning (OWASP / SCA)
* SAST (SonarQube)
* File system scan (Trivy FS)
* Image scan (Trivy Image)
* IaC scanning (Checkov)

Do not skip security stages unless explicitly told.

---

## 🧪 Change Strategy

Before making changes, Claude must:

1. Explain:

   * What will be changed
   * Why it is needed
   * Impact on existing setup

2. Provide:

   * Exact file changes
   * Commands (if any)

3. Wait for approval

---

## 📁 Repository Guidelines

* Keep structure clean and modular
* Follow naming conventions:

  * Lowercase, hyphen-separated
* Do not create unnecessary files

---

## ⚠️ Error Handling

If unsure about:

* Architecture
* Tool choice
* Implementation approach

👉 Ask for clarification instead of guessing

---

## 🎯 Goal

Maintain a **production-grade, portfolio-ready DevSecOps project**
with clean structure, proper security integration, and real-world practices.
