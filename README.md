# TrustScore: DeFi Reputation Scoring Protocol

A decentralized, on-chain DeFi reputation scoring system built with Clarity for the Stacks blockchain.

## 📜 Overview

**TrustScore** is a secure, extensible reputation scoring protocol for DeFi users. It tracks and evaluates user behavior—such as loan repayments, liquidation events, protocol interactions, and transaction patterns—to produce a dynamic trust score. This reputation score empowers lending protocols, DAOs, and DeFi applications to assess user credibility and manage risk effectively.

This contract enables:
- User registration and profiling
- Activity-based reputation adjustments
- Comprehensive behavioral analytics
- Risk scoring for DeFi protocols
- Lending limit recommendations

## 🚀 Features

- 📈 **Dynamic Scoring**: Automatically updates user scores based on on-chain activities.
- 🔐 **Immutable Risk Profiles**: Compute and store creditworthiness assessments at block-level granularity.
- 🧠 **Predictive Analysis**: Evaluate risk based on behavior trends, frequency, and age of account.
- 🔎 **Read-Only Insights**: Retrieve activity history, total users, or paused state of contract.
- 🛡️ **Protocol Integrity**: Includes access control and pausing capabilities.

## 🧱 Data Structures

### `user-reputation` (Map)
Tracks user trust profiles.
```clarity
{ user: principal } => {
  reputation-score: uint,
  total-transactions: uint,
  successful-loans: uint,
  liquidations: uint,
  last-activity: uint,
  registration-block: uint,
  is-active: bool
}
```

### `user-activities` (Map)

Stores user activity logs for reputation impact calculations.

```clarity
{ user: principal, activity-id: uint } => {
  activity-type: uint,
  amount: uint,
  timestamp: uint,
  score-impact: int
}
```

### `reputation-history` (Map)

Keeps historical reputation data for trend and audit tracking.

```clarity
{ user: principal, period: uint } => {
  score: uint,
  timestamp: uint
}
```

## 📊 Scoring Logic

Activity types impact the reputation score as follows:

| Activity Type           | Code | Impact |
| ----------------------- | ---- | ------ |
| Loan Repaid             | `u1` | `+10`  |
| Liquidated              | `u2` | `-50`  |
| Large Transaction (>1M) | `u3` | `+5`   |
| Protocol Interaction    | `u4` | `+2`   |
| Governance Vote         | `u5` | `+3`   |

Scores are clamped between `0` and `1000`.

## 🧠 Risk Assessment

The `calculate-comprehensive-risk-profile` function produces:

* **Risk Level**: Value `1` (Low) to `5` (Very High)
* **Creditworthiness**: Scale `0–10`
* **Loan Limits**: Adjusted from `10K` to `1M` based on risk
* **Ratios**: Liquidation %, Success %, Transaction frequency

This enables informed credit and governance decisions.

## 🛠️ Usage

### Register a User

```clarity
(register-user)
```

### Record Activity

```clarity
(record-activity user-principal activity-type amount)
```

### Fetch Risk Profile

```clarity
(calculate-comprehensive-risk-profile user-principal)
```

## 🔐 Access Control

* Only the contract deployer (via `tx-sender`) is considered the owner.
* The contract can be paused using an admin function (implementation not shown here).

## 🧪 Development

Test and deploy with the [Clarinet](https://docs.stacks.co/write-smart-contracts/clarinet/overview) development framework.

```bash
clarinet test
clarinet integrate
```

## 🤝 Contributing

We welcome contributions to improve TrustScore Protocol.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/YourFeature`)
3. Commit your changes (`git commit -am 'Add your feature'`)
4. Push to the branch (`git push origin feature/YourFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## 🔗 Related Links

* [Stacks Blockchain](https://www.stacks.co)
* [Clarinet by Hiro](https://github.com/hirosystems/clarinet)
* [ALEX DeFi](https://www.alexgo.io/)

---

**TrustScore Protocol** — Building trust, one block at a time. ⛓️
