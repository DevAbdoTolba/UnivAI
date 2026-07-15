---
theme: default
routerMode: hash
title: Week 3 — Fault Tolerance and Consensus
---

# Week 3
## Fault Tolerance and Consensus

---

# Network Delays and NTP Synchronization

- Node firewalls may go unnoticed for some time
- NTP synchronization is limited by network delay

<small>Source: p.312</small>

---

# Fault Tolerance and Consensus

- Detecting faults is hard
- Timeouts can’t distinguish between network and node failures

<small>Source: p.333</small>

---

# Linearizability and Quorums

- Strict quorum reads are linearizable
- However, nonlinearizable behavior is possible due to clock skew

<small>Source: p.356</small>
