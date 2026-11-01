# Blood Bank Coordination System
### Next.js + MySQL 8 + MongoDB

A web-based blood bank management and coordination system designed to streamline blood donations, manage blood inventory, handle hospital requests, and facilitate compatible blood matching.

The system combines **MySQL 8** for structured relational data management and **MongoDB** for maintaining an append-only audit trail of application changes.

## Technology Stack

- **Frontend:** Next.js
- **Relational Database:** MySQL 8
- **NoSQL Database:** MongoDB
- **Password Security:** bcrypt hashing

## Database Architecture

### MySQL – Relational Database

MySQL stores the core application data in the `blood_bank_system` database. The database schema is defined in `db/schema.sql`.

It includes:

- Tables for donors, donations, blood inventory, hospitals, blood requests, camps, and users.
- Views for retrieving and presenting meaningful data.
- Triggers for automated database operations and integrity enforcement.
- Stored procedures:
  - `sp_RegisterDonation` – Handles donation registration and related database operations.
  - `sp_ConfirmMatch` – Confirms compatible blood matches and updates inventory accordingly.

### MongoDB – NoSQL Database

MongoDB maintains an append-only audit log in `bloodbank_nosql.audit_log`.

It records application changes and provides a historical trail of important operations.

MongoDB is optional. The application works without it, but the Audit Trail section displays an availability notice when MongoDB is not connected.

## Application Modules

| Module | Description |
|---|---|
| **Overview** | Displays current blood stock, critical hospital requests, units nearing expiry, and donors eligible for their next donation. |
| **Inventory** | Tracks blood availability across hospitals, manages unit status changes, and handles expired blood unit disposal. |
| **Requests & Matching** | Creates hospital blood requests, identifies compatible blood units using ABO/Rh compatibility rules, proposes and confirms matches, fulfils requests, and cancels requests while releasing reserved units. |
| **Donors** | Supports donor registration and management, including adding, editing, and deleting donor records. |
| **Donations** | Registers donations through `sp_RegisterDonation`, verifies donor eligibility, and enforces the minimum 56-day interval between donations. |
| **Camps** | Manages blood donation camp records and related information. |
| **Hospitals** | Maintains hospital details and supports hospital record management. |
| **Users** | Manages application users and securely stores passwords using bcrypt hashing. |
| **Eligibility** | Records donor eligibility assessments and supports full-text searching of remarks using MySQL `MATCH ... AGAINST`. |
| **Audit Trail** | Retrieves historical application changes from MongoDB. |

## Key Features

- Centralized blood inventory management.
- Blood availability tracking across hospitals.
- ABO and Rh-based blood compatibility matching.
- Automated donor eligibility and donation interval checks.
- Hospital blood request management and fulfilment.
- Stored procedure-based donation registration and match confirmation.
- Secure password storage using bcrypt.
- Full-text search for donor eligibility remarks.
- MongoDB-based append-only audit logging.
- Dashboard displaying important operational information.

## Prerequisites

Make sure the following are installed:

- Node.js and npm
- MySQL 8
- MongoDB (optional)

## Installation and Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd <project-folder>
```

### 2. Initialize the MySQL Database

Run the following command from the project root:

```bash
mysql -u root -p < db/schema.sql
```

This creates or recreates the `blood_bank_system` database, including its tables, views, triggers, stored procedures, and sample data.

**Note:** Running this script may replace existing database contents.

### 3. Start MongoDB (Optional)

Start your local MongoDB server if you want to use the Audit Trail module.

The application can run without MongoDB.

### 4. Configure Environment Variables

Copy the example environment file:

```bash
cp .env.example .env.local
```

Update `.env.local` with your MySQL credentials and other required database connection settings.

### 5. Install Dependencies

```bash
npm install
```

### 6. Start the Development Server

```bash
npm run dev
```

Open the application in your browser:

**http://localhost:3000**

## Project Objective

The primary objective of the Blood Bank Coordination System is to improve the efficiency of blood bank operations by integrating donor management, donation tracking, inventory monitoring, and hospital blood requests into a unified platform.

By combining relational database operations with NoSQL audit logging, the project demonstrates the practical application of SQL and NoSQL database technologies in a real-world blood bank coordination scenario.
