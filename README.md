# Blood Bank Coordination System

A web-based application for managing blood donors, donations, blood inventory, hospital requests, and blood matching.

## Tech Stack

- **Frontend:** Next.js 14, React 18
- **Backend:** Next.js API Routes
- **Database:** MySQL 8
- **NoSQL:** MongoDB
- **Password Hashing:** bcryptjs

## Features

- **Dashboard:** Overview of blood stock, requests, donations, and donors.
- **Inventory Management:** Track blood units across hospitals and manage their status.
- **Donor Management:** Add, update, view, and delete donor records.
- **Donation Management:** Register donations and check donor eligibility with a 56-day donation interval.
- **Requests & Matching:** Manage hospital blood requests and find compatible blood units using ABO/Rh rules.
- **Eligibility:** Record donor eligibility checks and search remarks.
- **Camps & Hospitals:** Manage donation camps and hospital records.
- **User Management:** Manage user accounts and roles.
- **Audit Trail:** Store and view application activity using MongoDB.

## Database

**MySQL 8**
- 11 tables
- 3 views
- 3 triggers
- 2 stored procedures
- Constraints, indexes, transactions, and full-text search.

**MongoDB**
- Stores application activity in the `bloodbank_nosql.audit_log` collection.
- Optional; the application works without MongoDB.

## Installation and Setup

### Prerequisites
- Node.js and npm
- MySQL 8
- MongoDB (optional)

### 1. Clone the Repository

```bash
git clone https://github.com/meghanapillappa/blood_management.git
cd blood_management/bloodbank
```

### 2. Set Up MySQL

```bash
mysql -u root -p < db/schema.sql
```

### 3. Configure Environment Variables

```bash
cp .env.example .env.local
```

Update `.env.local` with your MySQL credentials and MongoDB connection string.

### 4. Install Dependencies and Run

```bash
npm install
npm run dev
```

Open **http://localhost:3000** in your browser.

## Project Objective

To simplify blood bank operations by providing a centralized platform for managing donors, donations, inventory, hospital requests, and blood compatibility matching using SQL and NoSQL database technologies.
