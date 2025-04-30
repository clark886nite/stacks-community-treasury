# Stacks Community Treasury Smart Contract

## Overview

The **Stacks Community Treasury** is a Clarity smart contract designed to manage community funds on the Stacks blockchain in a transparent, secure, and programmable way. It allows STX holders, administrators, or DAOs to collect contributions, submit proposals, and approve funding for community-driven initiatives.

## Key Features

- 💰 **STX Fund Management**: Securely stores STX contributed by the community or external sources.
- 📜 **Proposal System**: Allows users or admins to create funding proposals with recipient and amount details.
- ✅ **Approval & Disbursement**: Enables controlled release of funds only after a proposal is approved.
- 🔍 **On-Chain Transparency**: Full on-chain record of proposals, approvals, and treasury activity.
- 🛠️ **Admin Controls**: Basic governance functions for approving proposals and managing funds.

## Contract Functions

- `submit-proposal`: Submit a new funding proposal.
- `approve-proposal`: Admin function to approve a pending proposal.
- `execute-proposal`: Transfer STX to a recipient once the proposal is approved.
- `get-proposal`: View details of a specific proposal.
- `get-balance`: Check current STX balance in the treasury.

## Usage Scenarios

- DAO-controlled community funding
- Grant and bounty distribution
- Treasury management for open-source projects
- Public goods and infrastructure support on Stacks

## Development & Testing

Built using [Clarinet](https://docs.stacks.co/docs/clarity/clarinet/overview/), the official toolchain for developing and testing Clarity smart contracts.


```bash
clarinet test
