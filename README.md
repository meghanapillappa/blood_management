# Blood Bank Coordination System

A web-based application for managing blood donors, donations, blood inventory, hospital requests, and blood matching.

## Tech Stack

- **Frontend:** Next.js 14, React 18
- **Backend:** Next.js API Routes
- **SQL Database:** MySQL 8
- **NoSQL Database:** MongoDB
- **Password Hashing:** bcryptjs

## Features

- **Dashboard:** Overview of blood stock, critical requests, expiring units, and donors eligible to donate again.
- **Inventory Management:** Track blood units across hospitals, update unit status, and discard expired units.
- **Donor Management:** Add, update, view, and delete donor records.
- **Donation Management:** Register donations and check donor eligibility with a 56-day donation interval.
- **Requests & Matching:** Manage hospital requests and find compatible blood units using ABO/Rh compatibility rules.
- **Eligibility:** Record eligibility checks and search remarks using MySQL full-text search.
- **Camps & Hospitals:** Manage donation camps and hospital records.
- **User Management:** Manage user accounts and roles with bcrypt password hashing.
- **Audit Trail:** Store and view application activity using MongoDB.

## Database Design

### MySQL 8 (SQL Database)

MySQL manages the structured application data.

- 11 tables
- 3 views
- 3 triggers
- 2 stored procedures:
  - `sp_RegisterDonation`
  - `sp_ConfirmMatch`
- Constraints, indexes, transactions, and full-text search.

The database schema and sample data are available in `db/schema.sql`.

### MongoDB (NoSQL Database)

MongoDB stores an append-only audit trail of application changes.

- Database: `bloodbank_nosql`
- Collection: `audit_log`
- MongoDB is optional. The application works without it, but the Audit Trail tab will show a notice.

## Installation and Setup

### Prerequisites

- Node.js and npm
- MySQL 8
- MongoDB (optional)

### 1. Clone the Repository

```bash
git clone https://github.com/meghanapillappa/blood_management.git
cd blood_management
```

### 2. Set Up MySQL

Run the following command from the project root:

```bash
mysql -u root -p < db/schema.sql
```

This creates the `blood_bank_system` database with sample data.

### 3. Configure Environment Variables

Copy the example environment file:

```bash
cp .env.example .env.local
```

Update `.env.local` with your MySQL password and MongoDB connection details.

**Never commit `.env.local` to GitHub.**

### 4. Install Dependencies

```bash
npm install
```

### 5. Start the Application

```bash
npm run dev
```

Open your browser and visit:

http://localhost:3000

## Application Modules

| Module | Functionality |
|---|---|
| Overview | Stock, requests, expiry alerts |
| Inventory | Blood unit and hospital stock management |
| Requests & Matching | Compatibility checking and matching |
| Donors | Donor records and eligibility |
| Donations | Donation registration |
| Eligibility | Eligibility checks and remarks search |
| Camps | Blood donation camp management |
| Hospitals | Hospital management |
| Users | User accounts and roles |
| Audit Trail | MongoDB activity logs |

## Project Objective

To simplify blood bank operations through a centralized platform for managing donors, donations, inventory, hospital requests, and blood compatibility matching using SQL and NoSQL database technologies.
