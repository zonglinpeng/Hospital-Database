set serveroutput on;

/* Drop all tables */

DROP TABLE Employees cascade constraints;
DROP TABLE GeneralManagers cascade constraints;
DROP TABLE DivisionManagers cascade constraints;
DROP TABLE RegularEmployees cascade constraints;
DROP TABLE Rooms cascade constraints;
DROP TABLE RoomServices cascade constraints;
DROP TABLE EmployeeRoomAccessGrants cascade constraints;
DROP TABLE EquipmentTypes cascade constraints;
DROP TABLE EquipmentUnits cascade constraints;
DROP TABLE Patients cascade constraints;
DROP TABLE Doctors cascade constraints;
DROP TABLE Admissions cascade constraints;
DROP TABLE Examinations cascade constraints;
DROP TABLE Stays cascade constraints;

/* Part 1 – Setup Tables */

/* Employees */

CREATE TABLE Employees (
  id INTEGER Primary Key,
  first_name VARCHAR2(32),
  last_name VARCHAR2(64),
  salary REAL,
  job_title VARCHAR2(128),
  office_number VARCHAR2(16)
);

CREATE TABLE GeneralManagers (
  employee_id INTEGER Primary Key,
  Constraint fk_gm_employee_id Foreign Key (employee_id) References Employees (id)
);

CREATE TABLE DivisionManagers (
  employee_id INTEGER Primary Key,
  general_manager_id INTEGER,
  Constraint fk_dm_eid Foreign Key (employee_id) References Employees (id),
  Constraint fk_dm_gm_id Foreign Key (general_manager_id) References GeneralManagers (employee_id)
);

CREATE TABLE RegularEmployees (
  employee_id INTEGER Primary Key,
  division_manager_id INTEGER,
  Constraint fk_re_eid Foreign Key (employee_id) References Employees (id),
  Constraint fk_re_dmid Foreign Key (division_manager_id) References DivisionManagers (employee_id)
);

/* Rooms */

CREATE TABLE Rooms (
  room_number VARCHAR2(16) Primary Key,
  is_occupied NUMBER(1) DEFAULT 0 NOT NULL /* 0 means not occupied */
);

CREATE TABLE RoomServices (
  type VARCHAR2(32),
  room_number VARCHAR2(16),
  Constraint fk_room_services_room_number Foreign Key (room_number) References Rooms (room_number),
  Constraint pk_room_services Primary Key (type, room_number)
);

CREATE TABLE EmployeeRoomAccessGrants (
  employee_id INTEGER,
  room_number VARCHAR2(16),
  Constraint fk_erag_eid Foreign Key (employee_id) References Employees (id),
  Constraint fk_erag_room_number Foreign Key (room_number) References Rooms (room_number),
  Constraint pk_erag Primary Key (employee_id, room_number)
);

/* Equipment */

CREATE TABLE EquipmentTypes (
  id INTEGER Primary Key,
  model VARCHAR2(64),
  description VARCHAR2(256),
  instructions VARCHAR2(256),
  number_of_units INTEGER DEFAULT 0 NOT NULL
);

CREATE TABLE EquipmentUnits (
  serial_number VARCHAR2(64) Primary Key,
  year_of_purchase INTEGER,
  last_inspection_time TIMESTAMP,
  room_number VARCHAR2(16) References Rooms (room_number),
  equipment_type_id INTEGER References EquipmentTypes (id)
);

/* Appointments */

CREATE TABLE Patients (
  ssn VARCHAR2(11) Primary Key,
  first_name VARCHAR2(32),
  last_name VARCHAR2(64),
  address VARCHAR2(128),
  phone VARCHAR2(16)
);

CREATE TABLE Doctors (
  id INTEGER Primary Key,
  gender NUMBER(1),
  specialty VARCHAR2(32),
  first_name VARCHAR2(32),
  last_name VARCHAR2(64)
);

CREATE TABLE Admissions (
  id INTEGER Primary Key,
  patient_ssn VARCHAR2(11),
  admit_date DATE,
  leave_date DATE,
  total_payment REAL,
  insurance_payment REAL,
  future_visit_date DATE,
  Constraint fk_admissions_patient_ssn Foreign Key (patient_ssn) References Patients (ssn)
);

CREATE TABLE Examinations (
  doctor_id INTEGER,
  admission_id INTEGER,
  comment_text VARCHAR2(256),
  Constraint fk_examinations_doctor_id Foreign Key (doctor_id) References Doctors (id),
  Constraint fk_examinations_admission_id Foreign Key (admission_id) References Admissions (id),
  Constraint pk_examination Primary Key (doctor_id, admission_id)
);

CREATE TABLE Stays (
  admission_id INTEGER,
  room_number VARCHAR2(16),
  start_date Date,
  end_date Date,
  Constraint fk_stays_admission_id Foreign Key (admission_id) References Admissions (id),
  Constraint fk_stays_room_number Foreign Key (room_number) References Rooms (room_number),
  Constraint pk_stays Primary Key (admission_id, room_number, start_date)
);

/* Part 2 – Triggers */

/* Q1 */
CREATE OR REPLACE Trigger commentRequiredForICU
BEFORE INSERT OR UPDATE ON Examinations
FOR EACH ROW
WHEN (new.comment_text is NULL)
DECLARE
  number_of_icu_admissions INTEGER;
BEGIN
  SELECT COUNT(admission_id) into number_of_icu_admissions
  FROM Stays, RoomServices
  WHERE Stays.room_number = RoomServices.room_number
  AND RoomServices.type = 'ICU'
  AND Stays.admission_id = :new.admission_id;

  IF (number_of_icu_admissions > 0) THEN
    RAISE_APPLICATION_ERROR(-20004, 'ICU examinations must have a comment');
  END IF;
END;
/

/* Q2 */
CREATE OR REPLACE Trigger setInsurancePayment
BEFORE INSERT OR UPDATE ON Admissions
FOR EACH ROW
BEGIN
  :new.insurance_payment := :new.total_payment * 0.65;
END;
/

/* Q3 */
/* This could be done way more easily in our schema with just a NOT NULL constraint but using triggers anyways for the assignment.
We do not need to check that the employees boss is a division manager because this will be enforced by foreign key constraints */
CREATE OR REPLACE Trigger regEmpsMustHaveDivMans
BEFORE INSERT OR UPDATE ON RegularEmployees
FOR EACH ROW
BEGIN
  IF (:new.division_manager_id is NULL) THEN
    RAISE_APPLICATION_ERROR(-20004, 'Regular employees must have division managers');
  END IF;
END;
/

/* Q4 */
CREATE OR REPLACE Trigger divMansMustHaveGenMans
BEFORE INSERT OR UPDATE ON DivisionManagers
FOR EACH ROW
BEGIN
  IF (:new.general_manager_id is NULL) THEN
    RAISE_APPLICATION_ERROR(-20004, 'Division managers must have general managers');
  END IF;
END;
/

/* Q5 */
CREATE OR REPLACE Trigger setFutureVisitDateForERVisits
AFTER INSERT ON Stays
FOR EACH ROW
DECLARE
  has_er INTEGER;
BEGIN
  SELECT (CASE WHEN COUNT(room_number) > 0 THEN 1 ELSE 0 END) into has_er
  FROM RoomServices
  WHERE RoomServices.room_number = :new.room_number
  AND type = 'Emergency';

  IF (has_er = 1) THEN
    UPDATE Admissions
    SET future_visit_date = ADD_MONTHS(:new.start_date, 2)
    WHERE id = :new.admission_id;
  END IF;
END;
/

-- Examples
-- INSERT INTO Admissions (id, patient_ssn, admit_date, leave_date, total_payment, insurance_payment, future_visit_date) VALUES (15, '606-26-6462', TO_DATE('2018-01-25','YYYY-MM-DD'), TO_DATE('2018-01-25','YYYY-MM-DD'), 210.04, 40.13, NULL);
-- INSERT INTO Stays (admission_id, room_number, start_date, end_date) VALUES (15, 'A-102', TO_DATE('2018-01-25','YYYY-MM-DD'), TO_DATE('2018-01-25','YYYY-MM-DD'));
-- SELECT * FROM Admissions WHERE id = 15;

/* Q6 */
CREATE OR REPLACE Trigger ensRadEquipIsModern
BEFORE INSERT ON EquipmentUnits
FOR EACH ROW
DECLARE
  is_equipment_radiology INTEGER;
BEGIN
  SELECT COUNT(id) into is_equipment_radiology
  FROM EquipmentTypes
  WHERE id = :new.equipment_type_id
  AND model in ('CT Scanner', 'Ultrasound');

  IF (is_equipment_radiology <> 0 AND (:new.year_of_purchase is NULL OR :new.year_of_purchase <= 2006)) THEN
    RAISE_APPLICATION_ERROR(-20004, 'CT Scanners and Ultrasound machines must have a year of purchase that is after 2006.');
  END IF;
END;
/

-- Examples
-- INSERT INTO EquipmentUnits (equipment_type_id, room_number, serial_number, year_of_purchase, last_inspection_time) VALUES (4, 'C-303', 'bWP6JPRD2', 2006, timestamp '2018-02-19 11:27:00');

/* Q7 */


CREATE OR REPLACE Trigger printPatientInfoOnLeave
AFTER UPDATE ON Admissions
FOR EACH ROW
DECLARE
  first_name VARCHAR2(32);
  last_name VARCHAR2(64);
  address VARCHAR2(128);

  doctor_name VARCHAR2(32);
  doctor_comment VARCHAR2(256);

  CURSOR C1 IS (
    SELECT Doctors.first_name, comment_text
    FROM Examinations, Doctors
    WHERE Examinations.doctor_id = Doctors.id
    AND admission_id = :new.id
  );
BEGIN
  SELECT first_name, last_name, address INTO first_name, last_name, address
  FROM Patients
  WHERE ssn = :new.patient_ssn;

  dbms_output.put_line('First Name: ' || first_name);
  dbms_output.put_line('Last Name: ' || last_name);
  dbms_output.put_line('Address: ' || address);

  OPEN C1;
  LOOP
    FETCH C1 into doctor_name, doctor_comment;
    IF (C1%FOUND) THEN
      dbms_output.put_line(doctor_name || ': ' || doctor_comment);
    END IF;
    EXIT WHEN C1%NOTFOUND;
  END LOOP;
  CLOSE C1;
END;
/

-- Examples
-- UPDATE Admissions SET leave_date=TO_DATE('2018-01-17','YYYY-MM-DD') WHERE id=3;
-- UPDATE Admissions SET leave_date=TO_DATE('2018-01-22','YYYY-MM-DD') WHERE id=9;

/* Part 3 – Insert Data */

/* Rooms */

INSERT INTO Rooms (room_number, is_occupied) VALUES ('A-101', 0);
INSERT INTO Rooms (room_number, is_occupied) VALUES ('A-102', 0);
INSERT INTO Rooms (room_number, is_occupied) VALUES ('A-103', 0);
INSERT INTO Rooms (room_number, is_occupied) VALUES ('A-104', 1);
INSERT INTO Rooms (room_number, is_occupied) VALUES ('B-201', 0);
INSERT INTO Rooms (room_number, is_occupied) VALUES ('B-202', 1);
INSERT INTO Rooms (room_number, is_occupied) VALUES ('B-203', 1);
INSERT INTO Rooms (room_number, is_occupied) VALUES ('B-204', 0);
INSERT INTO Rooms (room_number, is_occupied) VALUES ('C-301', 1);
INSERT INTO Rooms (room_number, is_occupied) VALUES ('C-302', 0);
INSERT INTO Rooms (room_number, is_occupied) VALUES ('C-303', 0);

/* RoomServices */

INSERT INTO RoomServices (type, room_number) VALUES ('MRI', 'A-101');
INSERT INTO RoomServices (type, room_number) VALUES ('X-Ray', 'A-101');
INSERT INTO RoomServices (type, room_number) VALUES ('Teeth Cleaning', 'A-101');

INSERT INTO RoomServices (type, room_number) VALUES ('Teeth Cleaning', 'A-102');
INSERT INTO RoomServices (type, room_number) VALUES ('Brain Surgury', 'A-102');
INSERT INTO RoomServices (type, room_number) VALUES ('ICU', 'A-102');

INSERT INTO RoomServices (type, room_number) VALUES ('Heart Surgury', 'B-203');
INSERT INTO RoomServices (type, room_number) VALUES ('Ultrasound', 'B-203');
INSERT INTO RoomServices (type, room_number) VALUES ('Emergency', 'B-203');
/* Patients */

INSERT INTO Patients (ssn, first_name, last_name, address, phone) VALUES ('233-08-3422', 'Emma', 'Garza', '4762 Glendale Avenue, Northridge, CA 91324', '818-677-1608');
INSERT INTO Patients (ssn, first_name, last_name, address, phone) VALUES ('111-22-3333', 'George', 'Holliday', '1748 Timber Oak Drive, San Luis Obispo, CA 93401', '805-926-9638');
INSERT INTO Patients (ssn, first_name, last_name, address, phone) VALUES ('451-35-6785', 'Stephen', 'Dattilo', '4694 Oakridge Lane, Hawkinsville, GA 31036', '478-271-3998');
INSERT INTO Patients (ssn, first_name, last_name, address, phone) VALUES ('572-12-0888', 'Mathew', 'Ryan', '1402 Despard Street, Atlanta, GA 30303', '404-729-8321');
INSERT INTO Patients (ssn, first_name, last_name, address, phone) VALUES ('606-26-6462', 'Jennifer', 'Thomas', '4154 Pratt Avenue, Orchards, WA 98662', '360-883-5987');
INSERT INTO Patients (ssn, first_name, last_name, address, phone) VALUES ('481-18-2679', 'Andrew', 'Bentley', '3313 Wilkinson Court, Fort Myers, FL 33905', '239-745-3798');
INSERT INTO Patients (ssn, first_name, last_name, address, phone) VALUES ('780-46-8909', 'Douglas', 'Traylor', '2711 Philli Lane, Miami, OK 74354', '918-541-2872');
INSERT INTO Patients (ssn, first_name, last_name, address, phone) VALUES ('512-39-2408', 'Curt', 'Andrew', '4307 Driftwood Road, San Jose, CA 95129', '408-374-2811');
INSERT INTO Patients (ssn, first_name, last_name, address, phone) VALUES ('671-11-0388', 'Jane', 'Horton', '71 Sundown Lane, Austin, TX 78701', '512-279-0155');
INSERT INTO Patients (ssn, first_name, last_name, address, phone) VALUES ('663-57-8357', 'Alberto', 'Whaley', '2349 Massachusetts Avenue, Washington, DC 20020', '202-757-1036');

/* Doctors */

INSERT INTO Doctors (id, gender, specialty, first_name, last_name) VALUES (1, 0, 'General Pediatrics', 'Juanita', 'Elder');
INSERT INTO Doctors (id, gender, specialty, first_name, last_name) VALUES (2, 0, 'Dentistry', 'Alisha', 'Lee');
INSERT INTO Doctors (id, gender, specialty, first_name, last_name) VALUES (3, 0, 'Orthodontics', 'Brian', 'Kaczmarek');
INSERT INTO Doctors (id, gender, specialty, first_name, last_name) VALUES (4, 0, 'Heart Surgury', 'Lawrence', 'Martinez');
INSERT INTO Doctors (id, gender, specialty, first_name, last_name) VALUES (5, 0, 'Brain Surgury', 'Rachel', 'Thompson');
INSERT INTO Doctors (id, gender, specialty, first_name, last_name) VALUES (6, 0, 'Radiology', 'Alexander', 'Sutherland');
INSERT INTO Doctors (id, gender, specialty, first_name, last_name) VALUES (7, 0, 'Plastic Surgury', 'Kathy', 'McKenzie');
INSERT INTO Doctors (id, gender, specialty, first_name, last_name) VALUES (8, 0, 'Radiology', 'Ann', 'Bell');
INSERT INTO Doctors (id, gender, specialty, first_name, last_name) VALUES (9, 0, 'Anesthesiologist', 'Angel', 'Morales');
INSERT INTO Doctors (id, gender, specialty, first_name, last_name) VALUES (10, 0, 'Neonatologist', 'Carroll', 'Ramirez');

/* Admissions */

INSERT INTO Admissions (id, patient_ssn, admit_date, leave_date, total_payment, insurance_payment, future_visit_date) VALUES (2, '233-08-3422', TO_DATE('2018-01-16','YYYY-MM-DD'), TO_DATE('2018-01-16','YYYY-MM-DD'), 210.04, 120.13, NULL);
INSERT INTO Admissions (id, patient_ssn, admit_date, leave_date, total_payment, insurance_payment, future_visit_date) VALUES (1, '233-08-3422', TO_DATE('2018-01-15','YYYY-MM-DD'), TO_DATE('2018-01-15','YYYY-MM-DD'), 200.22, 150.01, TO_DATE('2018-02-22','YYYY-MM-DD'));

INSERT INTO Admissions (id, patient_ssn, admit_date, leave_date, total_payment, insurance_payment, future_visit_date) VALUES (3, '111-22-3333', TO_DATE('2018-01-17','YYYY-MM-DD'), TO_DATE('2018-01-17','YYYY-MM-DD'), 200.22, 160.01, TO_DATE('2018-03-01','YYYY-MM-DD'));
INSERT INTO Admissions (id, patient_ssn, admit_date, leave_date, total_payment, insurance_payment, future_visit_date) VALUES (4, '111-22-3333', TO_DATE('2018-03-01','YYYY-MM-DD'), TO_DATE('2018-03-01','YYYY-MM-DD'), 219.04, 11.97, TO_DATE('2018-05-02','YYYY-MM-DD'));
INSERT INTO Admissions (id, patient_ssn, admit_date, leave_date, total_payment, insurance_payment, future_visit_date) VALUES (12, '111-22-3333', TO_DATE('2018-05-02','YYYY-MM-DD'), TO_DATE('2018-05-02','YYYY-MM-DD'), 210.04, 70.13, TO_DATE('2018-06-24','YYYY-MM-DD'));

INSERT INTO Admissions (id, patient_ssn, admit_date, leave_date, total_payment, insurance_payment, future_visit_date) VALUES (5, '451-35-6785', TO_DATE('2018-01-18','YYYY-MM-DD'), TO_DATE('2018-01-18','YYYY-MM-DD'), 200.22, 152.01, TO_DATE('2018-09-03','YYYY-MM-DD'));
INSERT INTO Admissions (id, patient_ssn, admit_date, leave_date, total_payment, insurance_payment, future_visit_date) VALUES (6, '451-35-6785', TO_DATE('2018-01-18','YYYY-MM-DD'), TO_DATE('2018-01-19','YYYY-MM-DD'), 210.04, 140.13, NULL);

INSERT INTO Admissions (id, patient_ssn, admit_date, leave_date, total_payment, insurance_payment, future_visit_date) VALUES (7, '572-12-0888', TO_DATE('2018-01-20','YYYY-MM-DD'), TO_DATE('2018-01-20','YYYY-MM-DD'), 200.22, 172.01, NULL);
INSERT INTO Admissions (id, patient_ssn, admit_date, leave_date, total_payment, insurance_payment, future_visit_date) VALUES (8, '572-12-0888', TO_DATE('2018-01-21','YYYY-MM-DD'), TO_DATE('2018-01-21','YYYY-MM-DD'), 210.04, 50.13, NULL);
INSERT INTO Admissions (id, patient_ssn, admit_date, leave_date, total_payment, insurance_payment, future_visit_date) VALUES (9, '572-12-0888', TO_DATE('2018-01-22','YYYY-MM-DD'), TO_DATE('2018-01-22','YYYY-MM-DD'), 215.04, 21.13, NULL);
INSERT INTO Admissions (id, patient_ssn, admit_date, leave_date, total_payment, insurance_payment, future_visit_date) VALUES (13, '572-12-0888', TO_DATE('2018-01-29','YYYY-MM-DD'), TO_DATE('2018-01-29','YYYY-MM-DD'), 215.04, 21.13, NULL);
INSERT INTO Admissions (id, patient_ssn, admit_date, leave_date, total_payment, insurance_payment, future_visit_date) VALUES (14, '572-12-0888', TO_DATE('2018-01-30','YYYY-MM-DD'), TO_DATE('2018-01-30','YYYY-MM-DD'), 215.04, 21.13, NULL);

INSERT INTO Admissions (id, patient_ssn, admit_date, leave_date, total_payment, insurance_payment, future_visit_date) VALUES (10, '606-26-6462', TO_DATE('2018-01-22','YYYY-MM-DD'), TO_DATE('2018-01-22','YYYY-MM-DD'), 200.22, 110.01, NULL);
INSERT INTO Admissions (id, patient_ssn, admit_date, leave_date, total_payment, insurance_payment, future_visit_date) VALUES (11, '606-26-6462', TO_DATE('2018-01-23','YYYY-MM-DD'), TO_DATE('2018-01-23','YYYY-MM-DD'), 210.04, 40.13, NULL);

INSERT INTO Stays (admission_id, room_number, start_date, end_date) VALUES (2, 'B-203', TO_DATE('2018-01-16','YYYY-MM-DD'), TO_DATE('2018-01-16','YYYY-MM-DD'));

INSERT INTO Stays (admission_id, room_number, start_date, end_date) VALUES (3, 'A-102', TO_DATE('2018-01-17','YYYY-MM-DD'), TO_DATE('2018-01-18','YYYY-MM-DD'));

INSERT INTO Stays (admission_id, room_number, start_date, end_date) VALUES (7, 'A-102', TO_DATE('2018-01-20','YYYY-MM-DD'), TO_DATE('2018-01-20','YYYY-MM-DD'));
INSERT INTO Stays (admission_id, room_number, start_date, end_date) VALUES (8, 'A-102', TO_DATE('2018-01-21','YYYY-MM-DD'), TO_DATE('2018-01-21','YYYY-MM-DD'));
INSERT INTO Stays (admission_id, room_number, start_date, end_date) VALUES (9, 'A-102', TO_DATE('2018-01-22','YYYY-MM-DD'), TO_DATE('2018-01-22','YYYY-MM-DD'));
INSERT INTO Stays (admission_id, room_number, start_date, end_date) VALUES (13, 'A-102', TO_DATE('2018-01-29','YYYY-MM-DD'), TO_DATE('2018-01-29','YYYY-MM-DD'));
INSERT INTO Stays (admission_id, room_number, start_date, end_date) VALUES (13, 'A-102', TO_DATE('2018-01-30','YYYY-MM-DD'), TO_DATE('2018-01-30','YYYY-MM-DD'));

INSERT INTO Stays (admission_id, room_number, start_date, end_date) VALUES (10, 'A-102', TO_DATE('2018-01-22','YYYY-MM-DD'), TO_DATE('2018-01-22','YYYY-MM-DD'));
INSERT INTO Stays (admission_id, room_number, start_date, end_date) VALUES (11, 'A-102', TO_DATE('2018-01-23','YYYY-MM-DD'), TO_DATE('2018-01-23','YYYY-MM-DD'));


/* Equipment Types */

INSERT INTO EquipmentTypes (id, model, description, instructions, number_of_units) VALUES (1, 'X-Ray', 'Captures X-Rays', 'Very important instructions here', 3);
INSERT INTO EquipmentTypes (id, model, description, instructions, number_of_units) VALUES (2, 'MRI', 'Captures MRIs', 'Very important instructions here', 3);
INSERT INTO EquipmentTypes (id, model, description, instructions, number_of_units) VALUES (3, 'Centrifuge', 'Spins things really fast to seperate them', 'Very important instructions here', 4);
INSERT INTO EquipmentTypes (id, model, description, instructions, number_of_units) VALUES (4, 'CT Scanner', 'Does scans of the CT variety', 'Very important instructions here', 3);
INSERT INTO EquipmentTypes (id, model, description, instructions, number_of_units) VALUES (5, 'Ultrasound', 'Does ultrasounds', 'Very important instructions here', 3);

/* Equipment Units */

INSERT INTO EquipmentUnits (equipment_type_id, room_number, serial_number, year_of_purchase, last_inspection_time) VALUES (1, 'A-101', 'SYB7ZHFS', 2016, timestamp '2019-01-05 10:13:03');
INSERT INTO EquipmentUnits (equipment_type_id, room_number, serial_number, year_of_purchase, last_inspection_time) VALUES (1, 'B-201', 'B4VKV3N8', 2012, timestamp '2018-03-12 11:42:00');
INSERT INTO EquipmentUnits (equipment_type_id, room_number, serial_number, year_of_purchase, last_inspection_time) VALUES (1, 'C-301', 'M482AF95', 2019, timestamp '2019-01-22 21:23:00');

INSERT INTO EquipmentUnits (equipment_type_id, room_number, serial_number, year_of_purchase, last_inspection_time) VALUES (2, 'A-102', '95DGZL4X', 2011, timestamp '2019-01-03 05:19:00');
INSERT INTO EquipmentUnits (equipment_type_id, room_number, serial_number, year_of_purchase, last_inspection_time) VALUES (2, 'B-202', 'U7XVNRHE', 2012, timestamp '2018-08-14 01:44:00');
INSERT INTO EquipmentUnits (equipment_type_id, room_number, serial_number, year_of_purchase, last_inspection_time) VALUES (2, 'C-302', 'SNTF4N2H', 2016, timestamp '2017-07-31 14:31:00');

INSERT INTO EquipmentUnits (equipment_type_id, room_number, serial_number, year_of_purchase, last_inspection_time) VALUES (3, 'A-103', 'XUHG87A6', 2016, timestamp '2017-04-03 13:55:00');
INSERT INTO EquipmentUnits (equipment_type_id, room_number, serial_number, year_of_purchase, last_inspection_time) VALUES (3, 'B-203', 'A01-02X', 2012, timestamp '2018-03-16 08:36:00');
INSERT INTO EquipmentUnits (equipment_type_id, room_number, serial_number, year_of_purchase, last_inspection_time) VALUES (3, 'B-204', 'JF882FI8', 2015, timestamp '2018-01-10 03:14:00');
INSERT INTO EquipmentUnits (equipment_type_id, room_number, serial_number, year_of_purchase, last_inspection_time) VALUES (3, 'C-303', 'WP6JPRD2', 2011, timestamp '2018-02-19 11:27:00');

/* General Managers */

INSERT INTO Employees (id, first_name, last_name, salary, job_title, office_number) VALUES (1, 'Napoleon', 'Alberto', 72054.97, 'Government Administration Manager', 'A-131');
INSERT INTO GeneralManagers (employee_id) VALUES (1);
INSERT INTO Employees (id, first_name, last_name, salary, job_title, office_number) VALUES (2, 'Myrna', 'Jamison', 76871.08, 'National Education Manager', 'A-189');
INSERT INTO GeneralManagers (employee_id) VALUES (2);

/* Division Managers */

INSERT INTO Employees (id, first_name, last_name, salary, job_title, office_number) VALUES (3, 'Danilo', 'Manuel', 44426.34, 'Hospitality Consultant', 'A-131');
INSERT INTO DivisionManagers (employee_id, general_manager_id) VALUES (3, 1);
INSERT INTO Employees (id, first_name, last_name, salary, job_title, office_number) VALUES (4, 'Rutha', 'Jessie', 83264.25, 'Forward Agent', 'A-188');
INSERT INTO DivisionManagers (employee_id, general_manager_id) VALUES (4, 2);
INSERT INTO Employees (id, first_name, last_name, salary, job_title, office_number) VALUES (5, 'Gina', 'Breanne', 53998.3, 'Dynamic Retail Facilitator', 'A-149');
INSERT INTO DivisionManagers (employee_id, general_manager_id) VALUES (5, 1);
INSERT INTO Employees (id, first_name, last_name, salary, job_title, office_number) VALUES (10, 'Josiah', 'Belinda', 60685.84, 'Corporate Administration Officer', 'A-134');
INSERT INTO DivisionManagers (employee_id, general_manager_id) VALUES (10, 2);

/* Regular Employees */

INSERT INTO Employees (id, first_name, last_name, salary, job_title, office_number) VALUES (7, 'Calandra', 'Lorina', 75814.09, 'Insurance Billing Agent', 'A-129');
INSERT INTO RegularEmployees (employee_id, division_manager_id) VALUES (7, 10);
INSERT INTO Employees (id, first_name, last_name, salary, job_title, office_number) VALUES (8, 'Stephan', 'Adrian', 64705.03, 'Care Quality Agent', 'A-144');
INSERT INTO RegularEmployees (employee_id, division_manager_id) VALUES (8, 3);
INSERT INTO Employees (id, first_name, last_name, salary, job_title, office_number) VALUES (9, 'Lucila', 'Cecile', 47206.57, 'Direct Hospitality Developer', 'A-111');
INSERT INTO RegularEmployees (employee_id, division_manager_id) VALUES (9, 10);
INSERT INTO Employees (id, first_name, last_name, salary, job_title, office_number) VALUES (6, 'Ami', 'Willena', 94581.32, 'Real-Estate Secretary', 'A-139');
INSERT INTO RegularEmployees (employee_id, division_manager_id) VALUES (6, 10);
INSERT INTO Employees (id, first_name, last_name, salary, job_title, office_number) VALUES (11, 'Lavonia', 'Lanny', 55185.12, 'Hospitality Engineer', 'A-116');
INSERT INTO RegularEmployees (employee_id, division_manager_id) VALUES (11, 4);
INSERT INTO Employees (id, first_name, last_name, salary, job_title, office_number) VALUES (12, 'Enrique', 'Major', 41309.24, 'Chief Consultant', 'A-186');
INSERT INTO RegularEmployees (employee_id, division_manager_id) VALUES (12, 4);
INSERT INTO Employees (id, first_name, last_name, salary, job_title, office_number) VALUES (13, 'Lauretta', 'Emeline', 71280.84, 'District Banking Officer', 'A-186');
INSERT INTO RegularEmployees (employee_id, division_manager_id) VALUES (13, 3);
INSERT INTO Employees (id, first_name, last_name, salary, job_title, office_number) VALUES (14, 'Marilou', 'Merlyn', 74096.39, 'Junior Marketing Assistant', 'A-164');
INSERT INTO RegularEmployees (employee_id, division_manager_id) VALUES (14, 5);
INSERT INTO Employees (id, first_name, last_name, salary, job_title, office_number) VALUES (15, 'Dominica', 'Bo', 39581.96, 'Interior Decoration Assistant', 'A-117');
INSERT INTO RegularEmployees (employee_id, division_manager_id) VALUES (15, 3);
INSERT INTO Employees (id, first_name, last_name, salary, job_title, office_number) VALUES (16, 'Joey', 'Buddy', 41529.3, 'Corporate Accounting Intern', 'A-180');
INSERT INTO RegularEmployees (employee_id, division_manager_id) VALUES (16, 10);

/* Not required from Phase 2 document but needed to get queries to work */

INSERT INTO EmployeeRoomAccessGrants (employee_id, room_number) VALUES (1, 'A-102');
INSERT INTO EmployeeRoomAccessGrants (employee_id, room_number) VALUES (1, 'A-103');
INSERT INTO EmployeeRoomAccessGrants (employee_id, room_number) VALUES (2, 'A-102');
INSERT INTO EmployeeRoomAccessGrants (employee_id, room_number) VALUES (3, 'B-202');

INSERT INTO Examinations (doctor_id, admission_id, comment_text) VALUES (1, 3, 'I don''t have much to say');
INSERT INTO Examinations (doctor_id, admission_id, comment_text) VALUES (1, 4, 'I don''t have much to say');
INSERT INTO Examinations (doctor_id, admission_id, comment_text) VALUES (1, 12, 'I don''t have much to say');
INSERT INTO Examinations (doctor_id, admission_id, comment_text) VALUES (1, 5, 'I don''t have much to say');
INSERT INTO Examinations (doctor_id, admission_id, comment_text) VALUES (1, 6, 'I don''t have much to say');
INSERT INTO Examinations (doctor_id, admission_id, comment_text) VALUES (1, 7, 'I don''t have much to say');
INSERT INTO Examinations (doctor_id, admission_id, comment_text) VALUES (1, 8, 'I don''t have much to say');
INSERT INTO Examinations (doctor_id, admission_id, comment_text) VALUES (1, 9, 'I don''t have much to say');
INSERT INTO Examinations (doctor_id, admission_id, comment_text) VALUES (1, 10, 'I don''t have much to say');
INSERT INTO Examinations (doctor_id, admission_id, comment_text) VALUES (1, 11, 'I don''t have much to say');
INSERT INTO Examinations (doctor_id, admission_id, comment_text) VALUES (1, 1, 'I don''t have much to say');
INSERT INTO Examinations (doctor_id, admission_id, comment_text) VALUES (1, 2, 'I don''t have much to say');

INSERT INTO Examinations (doctor_id, admission_id, comment_text) VALUES (2, 3, 'I don''t have much to say');
INSERT INTO Examinations (doctor_id, admission_id, comment_text) VALUES (2, 7, 'This doesn''t look good...');
INSERT INTO Examinations (doctor_id, admission_id, comment_text) VALUES (2, 8, 'I''m not really sure what to do.');
INSERT INTO Examinations (doctor_id, admission_id, comment_text) VALUES (2, 9, 'I didn''t really goto medical school and this case is way over my head.');

/* Part 1 – Views */

/* Q1 */
CREATE OR REPLACE VIEW CriticalCases AS (
  SELECT Patients.ssn as Patient_SSN, first_name as firstName, last_name as lastName, AdmissionCount.admissions as numberOfAdmissionsToICU
  FROM Patients, (
      SELECT patient_ssn, COUNT(admission_id) as admissions
      FROM Stays, Admissions
      WHERE Stays.admission_id = Admissions.id
      AND room_number in (
          SELECT room_number
          FROM RoomServices
          WHERE type = 'ICU'
      )
      GROUP BY patient_ssn
      HAVING COUNT(admission_id) >= 2
  ) AdmissionCount
  WHERE Patients.ssn = AdmissionCount.patient_ssn
);

/* Q2 */
CREATE OR REPLACE VIEW DoctorsLoad AS (
  SELECT Doctors.id as DoctorID, CASE Doctors.gender
    WHEN 0 THEN 'female'
    WHEN 1 THEN 'male'
  END as gender, CASE WHEN DoctorLoad.exams > 10 THEN 'Overloaded'
      ELSE 'Underloaded'
  END as load
  FROM Doctors, (
      SELECT doctor_id, COUNT(DISTINCT admission_id) as exams
      FROM Examinations
      GROUP BY doctor_id
  ) DoctorLoad
  WHERE Doctors.id = DoctorLoad.doctor_id
);

/* Q3 */
SELECT *
FROM CriticalCases
WHERE numberOfAdmissionsToICU > 4;

/* Q4 */
SELECT Doctors.id, Doctors.first_name, Doctors.last_name
FROM DoctorsLoad, Doctors
WHERE DoctorsLoad.DoctorID = Doctors.id
AND DoctorsLoad.gender = 'female'
AND DoctorsLoad.load = 'Overloaded';

/* Q5 */
SELECT doctor_id, patient_ssn, comment_text
FROM Examinations, Admissions
WHERE Examinations.admission_id = Admissions.id
AND doctor_id IN (
    SELECT DoctorId
    FROM DoctorsLoad
    WHERE load = 'Underloaded'
)
AND patient_ssn IN (
    SELECT Patient_SSN
    FROM CriticalCases
);