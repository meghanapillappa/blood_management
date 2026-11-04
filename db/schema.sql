-- ============================================================================
-- BLOOD DONATION & HOSPITAL COORDINATION SYSTEM
-- Complete MySQL 8.x project script
-- Database: blood_bank_system
--
-- Run this entire file in MySQL Workbench / MySQL 8.x.
-- It recreates the database, creates schema objects, inserts sample data,
-- performs UPDATE and DELETE demonstrations, and runs verification queries.
-- ============================================================================

-- ============================================================================
-- PART 1: DDL - DATABASE AND TABLE CREATION
-- ============================================================================

DROP DATABASE IF EXISTS blood_bank_system;
CREATE DATABASE blood_bank_system;
USE blood_bank_system;

-- 1. Blood group lookup table
CREATE TABLE BloodGroup (
    blood_group_id INT AUTO_INCREMENT PRIMARY KEY,
    group_name VARCHAR(5) NOT NULL UNIQUE
);

-- 2. Hospital
CREATE TABLE Hospital (
    hospital_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    address VARCHAR(255) NOT NULL,
    phone VARCHAR(15) NOT NULL,
    email VARCHAR(100) UNIQUE,
    license_no VARCHAR(50) NOT NULL UNIQUE
);

-- 3. Donation camp
CREATE TABLE DonationCamp (
    camp_id INT AUTO_INCREMENT PRIMARY KEY,
    camp_name VARCHAR(100) NOT NULL,
    location VARCHAR(255) NOT NULL,
    organizer VARCHAR(100),
    camp_date DATE NOT NULL,
    start_time TIME,
    end_time TIME,
    CHECK (end_time IS NULL OR start_time IS NULL OR end_time > start_time)
);

-- 4. Donor
CREATE TABLE Donor (
    donor_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    gender ENUM('M','F','O') NOT NULL,
    dob DATE NOT NULL,
    phone VARCHAR(15) NOT NULL UNIQUE,
    email VARCHAR(100) UNIQUE,
    address VARCHAR(255),
    blood_group_id INT NOT NULL,
    registration_date DATE NOT NULL DEFAULT (CURRENT_DATE),
    password_hash VARCHAR(255),
    CONSTRAINT fk_donor_bloodgroup
        FOREIGN KEY (blood_group_id) REFERENCES BloodGroup(blood_group_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- 5. Eligibility check
CREATE TABLE EligibilityCheck (
    eligibility_id INT AUTO_INCREMENT PRIMARY KEY,
    donor_id INT NOT NULL,
    check_date DATE NOT NULL,
    hemoglobin_level DECIMAL(4,1),
    weight_kg DECIMAL(5,1),
    blood_pressure VARCHAR(10),
    is_eligible BOOLEAN NOT NULL,
    remarks VARCHAR(255),
    CONSTRAINT fk_eligibility_donor
        FOREIGN KEY (donor_id) REFERENCES Donor(donor_id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- 6. Donation
CREATE TABLE Donation (
    donation_id INT AUTO_INCREMENT PRIMARY KEY,
    donor_id INT NOT NULL,
    camp_id INT NULL,
    hospital_id INT NULL,
    donation_date DATE NOT NULL,
    quantity_ml INT NOT NULL,
    staff_name VARCHAR(100),
    CONSTRAINT fk_donation_donor
        FOREIGN KEY (donor_id) REFERENCES Donor(donor_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_donation_camp
        FOREIGN KEY (camp_id) REFERENCES DonationCamp(camp_id)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_donation_hospital
        FOREIGN KEY (hospital_id) REFERENCES Hospital(hospital_id)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CHECK (quantity_ml BETWEEN 200 AND 550)
);

-- 7. Blood unit
CREATE TABLE BloodUnit (
    unit_id INT AUTO_INCREMENT PRIMARY KEY,
    donation_id INT NOT NULL UNIQUE,
    blood_group_id INT NOT NULL,
    hospital_id INT NOT NULL,
    collection_date DATE NOT NULL,
    expiry_date DATE NOT NULL,
    status ENUM('Available','Reserved','Used','Discarded')
        NOT NULL DEFAULT 'Available',
    storage_location VARCHAR(50),
    CONSTRAINT fk_unit_donation
        FOREIGN KEY (donation_id) REFERENCES Donation(donation_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_unit_bloodgroup
        FOREIGN KEY (blood_group_id) REFERENCES BloodGroup(blood_group_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_unit_hospital
        FOREIGN KEY (hospital_id) REFERENCES Hospital(hospital_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CHECK (expiry_date > collection_date)
);

-- 8. Inventory
CREATE TABLE Inventory (
    inventory_id INT AUTO_INCREMENT PRIMARY KEY,
    hospital_id INT NOT NULL,
    blood_group_id INT NOT NULL,
    units_available INT NOT NULL DEFAULT 0,
    last_updated DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_inventory_hospital_group
        UNIQUE (hospital_id, blood_group_id),
    CONSTRAINT fk_inventory_hospital
        FOREIGN KEY (hospital_id) REFERENCES Hospital(hospital_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_inventory_bloodgroup
        FOREIGN KEY (blood_group_id) REFERENCES BloodGroup(blood_group_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CHECK (units_available >= 0)
);

-- 9. Blood request
CREATE TABLE BloodRequest (
    request_id INT AUTO_INCREMENT PRIMARY KEY,
    hospital_id INT NOT NULL,
    patient_name VARCHAR(100) NOT NULL,
    blood_group_id INT NOT NULL,
    units_required INT NOT NULL,
    request_date DATE NOT NULL,
    urgency_level ENUM('Low','Medium','High','Critical')
        NOT NULL DEFAULT 'Medium',
    status ENUM('Pending','Matched','Fulfilled','Cancelled')
        NOT NULL DEFAULT 'Pending',
    CONSTRAINT fk_request_hospital
        FOREIGN KEY (hospital_id) REFERENCES Hospital(hospital_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_request_bloodgroup
        FOREIGN KEY (blood_group_id) REFERENCES BloodGroup(blood_group_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CHECK (units_required > 0)
);

-- 10. Matching (associative entity between BloodRequest and BloodUnit)
CREATE TABLE Matching (
    match_id INT AUTO_INCREMENT PRIMARY KEY,
    request_id INT NOT NULL,
    unit_id INT NOT NULL,
    match_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status ENUM('Proposed','Confirmed','Rejected') NOT NULL DEFAULT 'Proposed',
    CONSTRAINT uq_matching_request_unit UNIQUE (request_id, unit_id),
    CONSTRAINT fk_matching_request
        FOREIGN KEY (request_id) REFERENCES BloodRequest(request_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_matching_unit
        FOREIGN KEY (unit_id) REFERENCES BloodUnit(unit_id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- 11. User account (role-based authentication)
CREATE TABLE UserAccount (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('Admin','HospitalStaff','Donor') NOT NULL,
    hospital_id INT NULL,
    donor_id INT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_user_hospital
        FOREIGN KEY (hospital_id) REFERENCES Hospital(hospital_id)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_user_donor
        FOREIGN KEY (donor_id) REFERENCES Donor(donor_id)
        ON UPDATE CASCADE ON DELETE SET NULL
    -- Role rule is enforced by triggers below: MySQL (error 3823) does not
    -- allow a CHECK on columns used in FKs with ON DELETE SET NULL.
);

-- Indexes for common lookups
CREATE INDEX idx_donor_bloodgroup ON Donor(blood_group_id);
CREATE INDEX idx_donation_donor ON Donation(donor_id);
CREATE INDEX idx_bloodunit_status ON BloodUnit(status);
CREATE INDEX idx_bloodunit_group_hosp ON BloodUnit(blood_group_id, hospital_id);
CREATE INDEX idx_request_status ON BloodRequest(status);
CREATE INDEX idx_request_group_hosp ON BloodRequest(blood_group_id, hospital_id);
CREATE INDEX idx_matching_request ON Matching(request_id);
CREATE INDEX idx_matching_unit ON Matching(unit_id);
CREATE INDEX idx_user_role ON UserAccount(role);

-- ============================================================================
-- PART 2: SCHEMA EVOLUTION AND ADVANCED DATABASE FEATURES
-- ============================================================================

-- B1. ALTER TABLE: add city to Hospital
ALTER TABLE Hospital
    ADD COLUMN city VARCHAR(100) AFTER address;

CREATE INDEX idx_hospital_city ON Hospital(city);

-- B2. Full-text search on eligibility remarks
ALTER TABLE EligibilityCheck
    ADD FULLTEXT INDEX ftx_eligibility_remarks (remarks);

-- B3. Views
DROP VIEW IF EXISTS vw_AvailableInventory;
CREATE VIEW vw_AvailableInventory AS
SELECT h.hospital_id, h.name AS hospital_name, h.city,
       bg.group_name, i.units_available, i.last_updated
FROM Inventory i
JOIN Hospital h ON h.hospital_id = i.hospital_id
JOIN BloodGroup bg ON bg.blood_group_id = i.blood_group_id;

DROP VIEW IF EXISTS vw_PendingCriticalRequests;
CREATE VIEW vw_PendingCriticalRequests AS
SELECT r.request_id, r.patient_name, h.name AS hospital_name,
       bg.group_name, r.units_required, r.request_date, r.urgency_level
FROM BloodRequest r
JOIN Hospital h ON h.hospital_id = r.hospital_id
JOIN BloodGroup bg ON bg.blood_group_id = r.blood_group_id
WHERE r.status = 'Pending'
  AND r.urgency_level IN ('High','Critical');

DROP VIEW IF EXISTS vw_DonorDonationHistory;
CREATE VIEW vw_DonorDonationHistory AS
SELECT d.donor_id, d.name, bg.group_name,
       COUNT(dn.donation_id) AS total_donations,
       MAX(dn.donation_date) AS last_donation_date,
       SUM(dn.quantity_ml) AS total_ml_donated
FROM Donor d
JOIN BloodGroup bg ON bg.blood_group_id = d.blood_group_id
LEFT JOIN Donation dn ON dn.donor_id = d.donor_id
GROUP BY d.donor_id, d.name, bg.group_name;

-- B4. Triggers
DELIMITER $$

DROP TRIGGER IF EXISTS trg_bloodunit_after_insert $$
CREATE TRIGGER trg_bloodunit_after_insert
AFTER INSERT ON BloodUnit
FOR EACH ROW
BEGIN
    IF NEW.status = 'Available' THEN
        INSERT INTO Inventory (hospital_id, blood_group_id, units_available)
        VALUES (NEW.hospital_id, NEW.blood_group_id, 1)
        ON DUPLICATE KEY UPDATE units_available = units_available + 1;
    END IF;
END $$

DROP TRIGGER IF EXISTS trg_bloodunit_after_update $$
CREATE TRIGGER trg_bloodunit_after_update
AFTER UPDATE ON BloodUnit
FOR EACH ROW
BEGIN
    -- Unit left the Available pool
    IF OLD.status = 'Available' AND NEW.status <> 'Available' THEN
        UPDATE Inventory
        SET units_available = GREATEST(units_available - 1, 0)
        WHERE hospital_id = OLD.hospital_id
          AND blood_group_id = OLD.blood_group_id;
    END IF;

    -- Unit returned to the Available pool
    IF OLD.status <> 'Available' AND NEW.status = 'Available' THEN
        INSERT INTO Inventory (hospital_id, blood_group_id, units_available)
        VALUES (NEW.hospital_id, NEW.blood_group_id, 1)
        ON DUPLICATE KEY UPDATE units_available = units_available + 1;
    END IF;
END $$

DROP TRIGGER IF EXISTS trg_request_before_insert $$
CREATE TRIGGER trg_request_before_insert
BEFORE INSERT ON BloodRequest
FOR EACH ROW
BEGIN
    IF NEW.request_date < CURDATE() THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'request_date cannot be in the past';
    END IF;
END $$

DROP TRIGGER IF EXISTS trg_user_before_insert $$
CREATE TRIGGER trg_user_before_insert
BEFORE INSERT ON UserAccount
FOR EACH ROW
BEGIN
    IF (NEW.role = 'HospitalStaff' AND NEW.hospital_id IS NULL)
       OR (NEW.role = 'Donor' AND NEW.donor_id IS NULL) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'HospitalStaff needs a hospital; Donor needs a donor record';
    END IF;
END $$

DROP TRIGGER IF EXISTS trg_user_before_update $$
CREATE TRIGGER trg_user_before_update
BEFORE UPDATE ON UserAccount
FOR EACH ROW
BEGIN
    IF (NEW.role = 'HospitalStaff' AND NEW.hospital_id IS NULL)
       OR (NEW.role = 'Donor' AND NEW.donor_id IS NULL) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'HospitalStaff needs a hospital; Donor needs a donor record';
    END IF;
END $$

DELIMITER ;

-- B5. Stored procedures and transactions
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_ConfirmMatch $$
CREATE PROCEDURE sp_ConfirmMatch(IN p_match_id INT)
BEGIN
    DECLARE v_unit_id INT;
    DECLARE v_request_id INT;
    DECLARE v_unit_status VARCHAR(20);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT unit_id, request_id
    INTO v_unit_id, v_request_id
    FROM Matching
    WHERE match_id = p_match_id
    FOR UPDATE;

    SELECT status
    INTO v_unit_status
    FROM BloodUnit
    WHERE unit_id = v_unit_id
    FOR UPDATE;

    IF v_unit_status <> 'Available' THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Unit is no longer available';
    ELSE
        UPDATE BloodUnit
        SET status = 'Reserved'
        WHERE unit_id = v_unit_id;

        UPDATE Matching
        SET status = 'Confirmed'
        WHERE match_id = p_match_id;

        UPDATE Matching
        SET status = 'Rejected'
        WHERE unit_id = v_unit_id
          AND match_id <> p_match_id
          AND status = 'Proposed';

        UPDATE BloodRequest
        SET status = 'Matched'
        WHERE request_id = v_request_id;

        COMMIT;
    END IF;
END $$

DROP PROCEDURE IF EXISTS sp_RegisterDonation $$
CREATE PROCEDURE sp_RegisterDonation(
    IN p_donor_id INT,
    IN p_camp_id INT,
    IN p_hospital_id INT,
    IN p_quantity_ml INT,
    IN p_staff_name VARCHAR(100),
    IN p_blood_group_id INT,
    IN p_expiry_days INT
)
BEGIN
    DECLARE v_donation_id INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    INSERT INTO Donation
        (donor_id, camp_id, hospital_id, donation_date, quantity_ml, staff_name)
    VALUES
        (p_donor_id, p_camp_id, p_hospital_id, CURDATE(),
         p_quantity_ml, p_staff_name);

    SET v_donation_id = LAST_INSERT_ID();

    INSERT INTO BloodUnit
        (donation_id, blood_group_id, hospital_id,
         collection_date, expiry_date, status)
    VALUES
        (v_donation_id, p_blood_group_id, p_hospital_id, CURDATE(),
         DATE_ADD(CURDATE(), INTERVAL p_expiry_days DAY), 'Available');

    -- The BloodUnit insert trigger updates Inventory automatically.
    COMMIT;
END $$

DELIMITER ;

-- ============================================================================
-- PART 3: DML - INSERT SAMPLE DATA
-- ============================================================================

-- Seed blood groups. IDs: 1=A+, 2=A-, 3=B+, 4=B-, 5=AB+, 6=AB-, 7=O+, 8=O-
INSERT INTO BloodGroup (group_name) VALUES
('A+'), ('A-'), ('B+'), ('B-'), ('AB+'), ('AB-'), ('O+'), ('O-');

SET SQL_SAFE_UPDATES = 0;

-- 3.1 Hospitals
INSERT INTO Hospital (name, address, city, phone, email, license_no) VALUES
('City General Hospital', '12 Anna Salai', 'Chennai', '044-2811-1000',
 'info@citygeneral.example', 'TN-HOSP-0001'),
('Sunrise Medical Centre', '45 Race Course Road', 'Coimbatore', '0422-255-4000',
 'care@sunrisemed.example', 'TN-HOSP-0002'),
('Lakeview Regional Hospital', '8 Tallakulam Street', 'Madurai', '0452-234-7000',
 'admin@lakeview.example', 'TN-HOSP-0003'),
('St. Mary Community Hospital', '77 Cantonment Road', 'Trichy', '0431-241-9000',
 'contact@stmary.example', 'TN-HOSP-0004');

-- 3.2 Donation camps: two past camps and one upcoming camp
INSERT INTO DonationCamp
    (camp_name, location, organizer, camp_date, start_time, end_time)
VALUES
('Corporate Drive - Tidel Park', 'Tidel Park, Chennai', 'Rotary Club Chennai',
 DATE_SUB(CURDATE(), INTERVAL 60 DAY), '09:00:00', '15:00:00'),
('College Blood Camp', 'PSG College, Coimbatore', 'NSS Unit',
 DATE_SUB(CURDATE(), INTERVAL 20 DAY), '10:00:00', '16:00:00'),
('Community Health Fair', 'Town Hall, Madurai', 'Lions Club Madurai',
 DATE_ADD(CURDATE(), INTERVAL 15 DAY), '08:30:00', '13:30:00');

-- 3.3 Donors
INSERT INTO Donor
    (name, gender, dob, phone, email, address, blood_group_id, password_hash)
VALUES
('Arjun Kumar', 'M', '1990-04-12', '9800000001', 'arjun.k@example.com',
 'Adyar, Chennai', 7, '$2b$10$placeholderhash0000000000000001'),
('Priya Nair', 'F', '1994-08-23', '9800000002', 'priya.n@example.com',
 'RS Puram, Coimbatore', 1, '$2b$10$placeholderhash0000000000000002'),
('Rahul Verma', 'M', '1988-01-30', '9800000003', 'rahul.v@example.com',
 'Anna Nagar, Chennai', 3, NULL),
('Meena Iyer', 'F', '1996-11-05', '9800000004', 'meena.i@example.com',
 'KK Nagar, Madurai', 8, NULL),
('Karthik Raja', 'M', '1985-06-18', '9800000005', 'karthik.r@example.com',
 'Gandhipuram, Coimbatore', 5, NULL),
('Divya Menon', 'F', '1992-03-09', '9800000006', 'divya.m@example.com',
 'Srirangam, Trichy', 2, NULL),
('Sanjay Patel', 'M', '1999-12-01', '9800000007', 'sanjay.p@example.com',
 'T Nagar, Chennai', 4, NULL),
('Ananya Reddy', 'F', '1997-07-27', '9800000008', 'ananya.r@example.com',
 'Velachery, Chennai', 7, NULL),
('Vikram Singh', 'M', '1983-09-14', '9800000009', 'vikram.s@example.com',
 'Peelamedu, Coimbatore', 1, NULL),
('Lakshmi Devi', 'F', '1991-02-20', '9800000010', 'lakshmi.d@example.com',
 'Thillai Nagar, Trichy', 6, NULL),
('Test Donor', 'O', '2000-01-01', '9800000099', NULL, NULL, 7, NULL);

-- 3.4 Eligibility checks
INSERT INTO EligibilityCheck
    (donor_id, check_date, hemoglobin_level, weight_kg,
     blood_pressure, is_eligible, remarks)
VALUES
(1, DATE_SUB(CURDATE(), INTERVAL 120 DAY), 14.2, 72.0, '120/80',
 TRUE, 'Old routine check'),
(1, DATE_SUB(CURDATE(), INTERVAL 61 DAY), 14.5, 72.5, '118/78',
 TRUE, 'Healthy, cleared to donate'),
(2, DATE_SUB(CURDATE(), INTERVAL 21 DAY), 13.1, 58.0, '116/76',
 TRUE, 'Healthy'),
(3, DATE_SUB(CURDATE(), INTERVAL 21 DAY), 13.8, 80.0, '108/68',
 TRUE, 'Borderline low pressure, cleared'),
(4, DATE_SUB(CURDATE(), INTERVAL 61 DAY), 13.0, 55.0, '112/72',
 TRUE, 'Healthy'),
(5, DATE_SUB(CURDATE(), INTERVAL 21 DAY), 15.0, 85.0, '122/82',
 TRUE, 'Healthy'),
(7, DATE_SUB(CURDATE(), INTERVAL 4 DAY), 10.9, 62.0, '110/70',
 FALSE, 'Low hemoglobin, mild anemia suspected'),
(8, DATE_SUB(CURDATE(), INTERVAL 11 DAY), 13.5, 60.0, '115/75',
 TRUE, 'Healthy'),
(9, DATE_SUB(CURDATE(), INTERVAL 6 DAY), 14.8, 78.0, '124/84',
 TRUE, 'Healthy'),
(10, DATE_SUB(CURDATE(), INTERVAL 2 DAY), 12.8, 57.0, '104/66',
 FALSE, 'Low BP, recheck advised');

-- 3.5 Donations (explicit IDs so BloodUnit rows can reference them)
-- Camp donations have no hospital; direct donations have no camp.
INSERT INTO Donation
    (donation_id, donor_id, camp_id, hospital_id,
     donation_date, quantity_ml, staff_name)
VALUES
(1, 1, 1, NULL, DATE_SUB(CURDATE(), INTERVAL 60 DAY), 450, 'Nurse Priya'),
(2, 4, 1, NULL, DATE_SUB(CURDATE(), INTERVAL 60 DAY), 450, 'Nurse Priya'),
(3, 2, 2, NULL, DATE_SUB(CURDATE(), INTERVAL 20 DAY), 450, 'Nurse Kavitha'),
(4, 3, 2, NULL, DATE_SUB(CURDATE(), INTERVAL 20 DAY), 350, 'Nurse Kavitha'),
(5, 5, 2, NULL, DATE_SUB(CURDATE(), INTERVAL 20 DAY), 450, 'Nurse Kavitha'),
(6, 8, NULL, 1, DATE_SUB(CURDATE(), INTERVAL 10 DAY), 450, 'Nurse Deepa'),
(7, 6, NULL, 2, DATE_SUB(CURDATE(), INTERVAL 8 DAY), 450, 'Nurse Meera'),
(8, 9, NULL, 1, DATE_SUB(CURDATE(), INTERVAL 5 DAY), 450, 'Nurse Deepa'),
(9, 7, NULL, 3, DATE_SUB(CURDATE(), INTERVAL 3 DAY), 350, 'Nurse Latha'),
(10, 10, NULL, 3, DATE_SUB(CURDATE(), INTERVAL 1 DAY), 450, 'Nurse Latha');

-- 3.6 Seed zero-stock inventory for every hospital x blood group.
-- BloodUnit insert trigger increments the relevant inventory row.
INSERT INTO Inventory (hospital_id, blood_group_id, units_available)
SELECT h.hospital_id, bg.blood_group_id, 0
FROM Hospital h
CROSS JOIN BloodGroup bg;

-- 3.7 Blood units (42-day shelf life)
INSERT INTO BloodUnit
    (unit_id, donation_id, blood_group_id, hospital_id,
     collection_date, expiry_date, status, storage_location)
VALUES
(1, 1, 7, 1, DATE_SUB(CURDATE(), INTERVAL 60 DAY),
 DATE_ADD(DATE_SUB(CURDATE(), INTERVAL 60 DAY), INTERVAL 42 DAY),
 'Available', 'Fridge-A1'),
(2, 2, 8, 1, DATE_SUB(CURDATE(), INTERVAL 60 DAY),
 DATE_ADD(DATE_SUB(CURDATE(), INTERVAL 60 DAY), INTERVAL 42 DAY),
 'Available', 'Fridge-A1'),
(3, 3, 1, 1, DATE_SUB(CURDATE(), INTERVAL 20 DAY),
 DATE_ADD(DATE_SUB(CURDATE(), INTERVAL 20 DAY), INTERVAL 42 DAY),
 'Available', 'Fridge-A2'),
(4, 4, 3, 2, DATE_SUB(CURDATE(), INTERVAL 20 DAY),
 DATE_ADD(DATE_SUB(CURDATE(), INTERVAL 20 DAY), INTERVAL 42 DAY),
 'Available', 'Fridge-B1'),
(5, 5, 5, 2, DATE_SUB(CURDATE(), INTERVAL 20 DAY),
 DATE_ADD(DATE_SUB(CURDATE(), INTERVAL 20 DAY), INTERVAL 42 DAY),
 'Available', 'Fridge-B1'),
(6, 6, 7, 1, DATE_SUB(CURDATE(), INTERVAL 10 DAY),
 DATE_ADD(DATE_SUB(CURDATE(), INTERVAL 10 DAY), INTERVAL 42 DAY),
 'Available', 'Fridge-A3'),
(7, 7, 2, 2, DATE_SUB(CURDATE(), INTERVAL 8 DAY),
 DATE_ADD(DATE_SUB(CURDATE(), INTERVAL 8 DAY), INTERVAL 42 DAY),
 'Available', 'Fridge-B2'),
(8, 8, 1, 1, DATE_SUB(CURDATE(), INTERVAL 5 DAY),
 DATE_ADD(DATE_SUB(CURDATE(), INTERVAL 5 DAY), INTERVAL 42 DAY),
 'Available', 'Fridge-A2'),
(9, 9, 4, 3, DATE_SUB(CURDATE(), INTERVAL 3 DAY),
 DATE_ADD(DATE_SUB(CURDATE(), INTERVAL 3 DAY), INTERVAL 42 DAY),
 'Available', 'Fridge-C1'),
(10, 10, 6, 3, DATE_SUB(CURDATE(), INTERVAL 1 DAY),
 DATE_ADD(DATE_SUB(CURDATE(), INTERVAL 1 DAY), INTERVAL 42 DAY),
 'Available', 'Fridge-C1');

-- 3.8 Register another donation using the stored procedure.
-- Donor 4 is O- (blood_group_id 8), at hospital 3.
CALL sp_RegisterDonation(4, NULL, 3, 450, 'Nurse Latha', 8, 42);

-- 3.9 Blood requests (request_date cannot be in the past)
INSERT INTO BloodRequest
    (request_id, hospital_id, patient_name, blood_group_id,
     units_required, request_date, urgency_level, status)
VALUES
(1, 1, 'Ravi Shankar', 7, 2, CURDATE(), 'Critical', 'Pending'),
(2, 2, 'Sita Devi', 3, 1, CURDATE(), 'High', 'Pending'),
(3, 3, 'Mohan Das', 4, 1, DATE_ADD(CURDATE(), INTERVAL 1 DAY),
 'Medium', 'Pending'),
(4, 1, 'Fatima Begum', 1, 1, CURDATE(), 'Low', 'Pending'),
(5, 2, 'John Paul', 5, 1, CURDATE(), 'Medium', 'Pending'),
(6, 3, 'Cancel Me', 2, 1, CURDATE(), 'Low', 'Pending'),
(7, 2, 'Kavya Raman', 1, 1, CURDATE(), 'Medium', 'Pending');

-- 3.10 Proposed matches between requests and units
INSERT INTO Matching (match_id, request_id, unit_id, status) VALUES
(1, 1, 6, 'Proposed'), -- O+ unit for Ravi
(2, 1, 1, 'Proposed'), -- O+ unit which is expired; discarded in update section
(3, 2, 4, 'Proposed'), -- B+ unit for Sita
(4, 4, 8, 'Proposed'), -- A+ unit for Fatima
(5, 7, 8, 'Proposed'), -- competing proposal for the same A+ unit
(6, 3, 9, 'Proposed'); -- B- unit for Mohan

-- 3.11 User accounts
INSERT INTO UserAccount (email, password_hash, role, hospital_id, donor_id) VALUES
('admin@bloodbank.example', '$2b$10$placeholderhashadmin000000000',
 'Admin', NULL, NULL),
('staff@citygeneral.example', '$2b$10$placeholderhashstaff00000000',
 'HospitalStaff', 1, NULL),
('arjun.k@example.com', '$2b$10$placeholderhashdonor00000001',
 'Donor', NULL, 1),
('priya.n@example.com', '$2b$10$placeholderhashdonor00000002',
 'Donor', NULL, 2);

-- ============================================================================
-- PART 4: DML - UPDATE
-- ============================================================================

-- 4.1 Simple column updates
UPDATE Donor
SET phone = '9811111111',
    address = 'Besant Nagar, Chennai'
WHERE donor_id = 1;

UPDATE Hospital
SET phone = '044-2899-1000',
    email = 'contact@citygeneral.example'
WHERE hospital_id = 1;

-- 4.2 Update after a re-test: donor 7 is now cleared
UPDATE EligibilityCheck
SET remarks = 'Low hemoglobin, mild anemia suspected - superseded by re-test'
WHERE donor_id = 7 AND is_eligible = FALSE;

INSERT INTO EligibilityCheck
    (donor_id, check_date, hemoglobin_level, weight_kg,
     blood_pressure, is_eligible, remarks)
VALUES
(7, CURDATE(), 12.9, 62.0, '112/72', TRUE,
 'Hemoglobin recovered after iron supplements');

-- 4.3 Escalate a request's urgency
UPDATE BloodRequest
SET urgency_level = 'High'
WHERE request_id = 5;

-- 4.4 Discard expired units. Trigger reduces inventory automatically.
UPDATE BloodUnit
SET status = 'Discarded'
WHERE status = 'Available'
  AND expiry_date < CURDATE();

-- 4.5 Multi-table UPDATE: reject matches whose unit was discarded
UPDATE Matching m
JOIN BloodUnit u ON u.unit_id = m.unit_id
SET m.status = 'Rejected'
WHERE u.status = 'Discarded'
  AND m.status = 'Proposed';

-- 4.6 Confirm matches using the stored procedure.
-- Confirming match 4 also rejects competing match 5 for unit 8.
CALL sp_ConfirmMatch(1);
CALL sp_ConfirmMatch(3);
CALL sp_ConfirmMatch(4);

-- 4.7 Transfusion completed: mark unit Used and request Fulfilled
UPDATE BloodUnit
SET status = 'Used'
WHERE unit_id = 4;

UPDATE BloodRequest
SET status = 'Fulfilled'
WHERE request_id = 2;

-- 4.8 Cancel a request (deleted in the DELETE section)
UPDATE BloodRequest
SET status = 'Cancelled'
WHERE request_id = 6;

-- 4.9 Update using a subquery: upcoming camp starts at earliest past-camp time
UPDATE DonationCamp
SET start_time = (
    SELECT MIN(start_time)
    FROM (
        SELECT start_time
        FROM DonationCamp
        WHERE camp_date < CURDATE()
    ) AS past_camp_times
)
WHERE camp_id = 3;

-- 4.10 Deactivate a user account (soft delete)
UPDATE UserAccount
SET is_active = FALSE
WHERE email = 'priya.n@example.com';

-- 4.11 Bulk update using CASE
UPDATE BloodUnit
SET storage_location = CASE
    WHEN status = 'Discarded' THEN 'Disposal-Bin'
    WHEN status = 'Used' THEN NULL
    ELSE storage_location
END;

-- ============================================================================
-- PART 5: DML - DELETE / CLEANUP
-- ============================================================================

-- 5.1 Remove rejected matches
DELETE FROM Matching
WHERE status = 'Rejected';

-- 5.2 Remove cancelled requests (matching rows cascade)
DELETE FROM BloodRequest
WHERE status = 'Cancelled';

-- 5.3 Purge eligibility checks older than 90 days
DELETE FROM EligibilityCheck
WHERE check_date < DATE_SUB(CURDATE(), INTERVAL 90 DAY);

-- 5.4 Delete a donor with no donations (safe due to NOT EXISTS)
DELETE FROM Donor
WHERE donor_id = 11
  AND NOT EXISTS (
      SELECT 1
      FROM Donation
      WHERE donor_id = 11
  );

-- 5.5 Delete the cancelled future camp
DELETE FROM DonationCamp
WHERE camp_id = 3
  AND camp_date > CURDATE();

-- 5.6 Remove discarded units older than the retention window
DELETE FROM BloodUnit
WHERE status = 'Discarded'
  AND expiry_date < DATE_SUB(CURDATE(), INTERVAL 365 DAY);

-- The following would fail by design because Donation uses ON DELETE RESTRICT:
-- DELETE FROM Donor WHERE donor_id = 1;

-- ============================================================================
-- PART 6: SELECT - VERIFY RESULTS
-- ============================================================================

-- 6.1 Row counts
SELECT 'Hospital' AS tbl, COUNT(*) AS n FROM Hospital
UNION ALL SELECT 'Donor', COUNT(*) FROM Donor
UNION ALL SELECT 'Donation', COUNT(*) FROM Donation
UNION ALL SELECT 'BloodUnit', COUNT(*) FROM BloodUnit
UNION ALL SELECT 'BloodRequest', COUNT(*) FROM BloodRequest
UNION ALL SELECT 'Matching', COUNT(*) FROM Matching;

-- 6.2 Blood units and their current status
SELECT u.unit_id, bg.group_name, h.name AS hospital,
       u.collection_date, u.expiry_date, u.status
FROM BloodUnit u
JOIN BloodGroup bg ON bg.blood_group_id = u.blood_group_id
JOIN Hospital h ON h.hospital_id = u.hospital_id
ORDER BY u.unit_id;

-- 6.3 Inventory in stock (maintained by trigger)
SELECT *
FROM vw_AvailableInventory
WHERE units_available > 0
ORDER BY hospital_name, group_name;

-- 6.4 Request and match status
SELECT r.request_id, r.patient_name, bg.group_name,
       r.urgency_level, r.status AS request_status,
       m.match_id, m.unit_id, m.status AS match_status
FROM BloodRequest r
JOIN BloodGroup bg ON bg.blood_group_id = r.blood_group_id
LEFT JOIN Matching m ON m.request_id = r.request_id
ORDER BY r.request_id;

-- 6.5 Pending high/critical requests
SELECT *
FROM vw_PendingCriticalRequests;

-- 6.6 Donor donation history
SELECT *
FROM vw_DonorDonationHistory
ORDER BY total_donations DESC, donor_id;

-- 6.7 Donors eligible to donate again (last donation 56+ days ago, or never)
SELECT d.donor_id, d.name,
       MAX(dn.donation_date) AS last_donation
FROM Donor d
LEFT JOIN Donation dn ON dn.donor_id = d.donor_id
GROUP BY d.donor_id, d.name
HAVING last_donation IS NULL
    OR last_donation <= DATE_SUB(CURDATE(), INTERVAL 56 DAY);

-- 6.8 Full-text search of eligibility remarks
SELECT eligibility_id, donor_id, remarks
FROM EligibilityCheck
WHERE MATCH(remarks)
AGAINST ('anemia hemoglobin' IN NATURAL LANGUAGE MODE);

SET SQL_SAFE_UPDATES = 1;

-- ============================================================================
-- END OF PROJECT SQL SCRIPT
-- ============================================================================