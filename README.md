# Digital Jury Duty Management System

A comprehensive blockchain-based system for managing jury duty processes, from citizen selection to compensation tracking.

## Overview

This system consists of five interconnected smart contracts that handle the complete jury duty lifecycle:

1. **Citizen Selection Contract** - Randomly selects eligible jurors from voter registration rolls
2. **Scheduling Coordination Contract** - Manages court date assignments and scheduling conflicts
3. **Qualification Screening Contract** - Validates juror eligibility and processes exemption requests
4. **Compensation Tracking Contract** - Handles jury service payments and mileage reimbursements
5. **Postponement Management Contract** - Manages legitimate jury duty deferrals and rescheduling

## Features

### Citizen Selection
- Random juror selection from verified voter rolls
- Configurable jury pool sizes
- Automatic exclusion of recently served jurors
- Geographic distribution considerations

### Scheduling Coordination
- Court calendar integration
- Conflict detection and resolution
- Multi-court coordination
- Automated notification system

### Qualification Screening
- Age and citizenship verification
- Criminal background checks
- Medical exemption processing
- Professional conflict identification

### Compensation Tracking
- Daily service fee calculation
- Mileage reimbursement tracking
- Payment processing and records
- Tax documentation generation

### Postponement Management
- Valid reason verification
- Automatic rescheduling
- Maximum deferral limits
- Emergency postponement handling

## Contract Architecture

Each contract operates independently while maintaining data consistency through standardized interfaces. The system uses Clarity's built-in security features to ensure data integrity and prevent unauthorized access.

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js 18+ for testing
- Stacks wallet for deployment

### Installation

\`\`\`bash
git clone <repository-url>
cd jury-duty-management
npm install
\`\`\`

### Testing

\`\`\`bash
npm test
\`\`\`

### Deployment

\`\`\`bash
clarinet deploy --testnet
\`\`\`

## Usage

### Selecting Jurors
\`\`\`clarity
(contract-call? .citizen-selection select-jurors u12 u1001)
\`\`\`

### Scheduling Court Dates
\`\`\`clarity
(contract-call? .scheduling-coordination assign-court-date u1001 u20240315)
\`\`\`

### Processing Qualifications
\`\`\`clarity
(contract-call? .qualification-screening validate-juror u1001)
\`\`\`

### Tracking Compensation
\`\`\`clarity
(contract-call? .compensation-tracking record-service u1001 u5 u25)
\`\`\`

### Managing Postponements
\`\`\`clarity
(contract-call? .postponement-management request-postponement u1001 "medical-emergency")
\`\`\`

## Security Considerations

- All contracts implement proper access controls
- Sensitive data is encrypted where appropriate
- Audit trails are maintained for all operations
- Rate limiting prevents system abuse

## Contributing

Please read CONTRIBUTING.md for details on our code of conduct and the process for submitting pull requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
