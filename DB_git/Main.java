import java.sql.*;
import java.util.ArrayList;
import java.util.Scanner;

/**
 * Created by Zonglin and sambaumgarten */
public class Main {
    public static void main(String [] args) throws SQLException {
        if (args.length <= 2) {
            System.out.println("1- Report Patients Basic Information");
            System.out.println("2- Report Doctors Basic Information");
            System.out.println("3- Report Admissions Information");
            System.out.println("4- Update Admissions Payment");
            return;
        }

        String username = args[0];
        String password = args[1];

        DBConnection.username = username;
        DBConnection.password = password;

        switch (Integer.parseInt(args[2])) {
            case 1:
                new FindPatientInfoCommand().run();
                break;
            case 2:
                new FindDoctorInfoCommand().run();
                break;
            case 3:
                new FindAdmissionInfoCommand().run();
                break;
            case 4:
                new UpdateAdmissionPayment().run();
                break;
            default:
                System.err.println("Command not found");
                return;

        }

        DBConnection.getConnection().close();
    }
}

/* Connection */

class DBConnection {
    public static String username;
    public static String password;

    public static Connection getConnection() {
        try {
            try {
                Class.forName("oracle.jdbc.driver.OracleDriver");
            } catch (ClassNotFoundException e) {
                e.printStackTrace();
            }
            return DriverManager.getConnection  ("jdbc:oracle:thin:@oracle.wpi.edu:1521:orcl", username, password);
        } catch (SQLException e) {
            e.printStackTrace();
        }

        return null;
    }
}


/* Commands */

interface Command {
    void run();
}

class FindPatientInfoCommand implements Command {
    @Override
    public void run() {
        System.out.println("Enter Patient SSN:");

        Scanner reader = new Scanner(System.in);
        String ssn = reader.nextLine();
        reader.close();

        try {
            Patient patient = PatientDAO.getPatient(ssn);

            if (patient == null) {
                System.out.println("Couldn't find patient");
                return;
            }

            System.out.println("Patient SSN: " + patient.ssn);
            System.out.println("Patient First Name: " + patient.firstName);
            System.out.println("Patient Last Name: " + patient.lastName);
            System.out.println("Patient Address: " + patient.address);
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }
}

class FindDoctorInfoCommand implements Command {
    @Override
    public void run() {
        System.out.println("Enter Doctor ID:");

        Scanner reader = new Scanner(System.in);
        int doctorId = reader.nextInt();
        reader.close();

        try {
            Doctor doctor = DoctorDAO.getDoctor(doctorId);
            if (doctor == null) {
                System.err.println("Unable to find doctor");
                return;
            }

            System.out.println("Patient SSN: " + doctor.id);
            System.out.println("Patient First Name: " + doctor.firstName);
            System.out.println("Patient Last Name: " + doctor.lastName);
            System.out.println("Patient Gender: " + doctor.gender);
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }
}

class FindAdmissionInfoCommand implements Command {
    @Override
    public void run() {
        System.out.println("Enter Admission ID:");

        Scanner reader = new Scanner(System.in);
        int admissionId = reader.nextInt();
        reader.close();

        try {
            Admission admission = AdmissionsDAO.getAdmission(admissionId);
            if (admission == null) {
                System.err.println("Unable to find admission");
                return;
            }
            ArrayList<Stay> stays = StaysDAO.getStaysByAdmissionId(admissionId);
            ArrayList<Examination> examinations = ExaminationsDAO.getExaminationsByAdmissionId(admissionId);

            System.out.println("Admission ID: " + admission.id);
            System.out.println("Patient SSN: " + admission.patientSSN);
            System.out.println("Admission date (start date): " + admission.admitDate.toString());
            System.out.println("Total Payment: " + admission.totalPayment);
            System.out.println("Rooms:");
            for (Stay stay : stays) {
                System.out.println("\tRoom Num: " + stay.roomNumber + " FromDate: " + stay.startDate.toString() + " ToDate: " + stay.endDate.toString());
            }

            System.out.println("Doctors examined the patient in this admission:");
            for (Examination examination : examinations) {
                System.out.println("\tDoctor ID: " + examination.doctorId);
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }
}

class UpdateAdmissionPayment implements Command {
    @Override
    public void run() {
        System.out.println("Enter Admission Number:");

        Scanner reader = new Scanner(System.in);
        int admissionId = reader.nextInt();

        try {
            Admission admission = AdmissionsDAO.getAdmission(admissionId);
            if (admission == null) {
                System.err.println("Unable to find admission with that ID");
                return;
            }

            System.out.println("Enter the new total payment: ");
            double newTotalPayment = reader.nextDouble();

            AdmissionsDAO.setTotalPayment(admissionId, newTotalPayment);
        } catch (SQLException e) {
            e.printStackTrace();
        }

        reader.close();
    }
}

/* Data Access Objects */

class PatientDAO {
    public static Patient getPatient(String ssn) throws SQLException {
        Connection connection = DBConnection.getConnection();

        PreparedStatement statement = connection.prepareStatement("SELECT * FROM Patients WHERE ssn = ?");
        statement.setString(1, ssn);

        ResultSet results = statement.executeQuery();
        if (results.next()) {
            return new Patient(results.getString("ssn"), results.getString("first_name"), results.getString("last_name"), results.getString("address"), results.getString("phone"));
        }

        return null;
    }
}

class StaysDAO {
    public static ArrayList<Stay> getStaysByAdmissionId(int admission_id) throws SQLException {
        Connection connection = DBConnection.getConnection();

        PreparedStatement statement = connection.prepareStatement("SELECT * FROM Stays WHERE admission_id = ?");
        statement.setInt(1, admission_id);

        ArrayList<Stay> results = new ArrayList<Stay>();

        ResultSet resultSet = statement.executeQuery();
        while (resultSet.next()) {
            results.add(new Stay(resultSet.getInt("admission_id"), resultSet.getString("room_number"), resultSet.getDate("start_date"), resultSet.getDate("end_date")));
        }

        return results;
    }
}

class DoctorDAO {
    public static Doctor getDoctor(int id) throws SQLException {
        Connection connection = DBConnection.getConnection();

        PreparedStatement statement = connection.prepareStatement("SELECT * FROM Doctors WHERE id = ?");
        statement.setInt(1, id);

        ResultSet results = statement.executeQuery();
        if (results.next()) {
            return new Doctor(results.getInt("id"), Doctor.Gender.fromInt(results.getInt("gender")), results.getString("specialty"), results.getString("first_name"), results.getString("last_name"));
        }

        return null;
    }
}

class AdmissionsDAO {
    static Admission getAdmission(int id) throws SQLException {
        Connection connection = DBConnection.getConnection();

        PreparedStatement statement = connection.prepareStatement("SELECT * FROM Admissions WHERE id = ?");
        statement.setInt(1, id);

        ResultSet results = statement.executeQuery();
        if (results.next()) {
            return new Admission(
                    results.getInt("id"),
                    results.getString("patient_ssn"),
                    results.getDate("admit_date"),
                    results.getDate("leave_date"),
                    results.getDouble("total_payment"),
                    results.getDouble("insurance_payment"),
                    results.getDate("future_visit_date")
            );
        }

        return null;
    }

    static boolean setTotalPayment(int id, double total_payment) throws SQLException {
        Connection connection = DBConnection.getConnection();

        PreparedStatement statement = connection.prepareStatement("UPDATE Admissions SET total_payment = ? WHERE id = ?");
        statement.setDouble(1, total_payment);
        statement.setInt(2, id);

        return statement.execute();
    }
}

class ExaminationsDAO {
    static ArrayList<Examination> getExaminationsByAdmissionId(int admission_id) throws SQLException {
        Connection connection = DBConnection.getConnection();

        PreparedStatement statement = connection.prepareStatement("SELECT * FROM Examinations WHERE admission_id = ?");
        statement.setInt(1, admission_id);

        ArrayList<Examination> results = new ArrayList<Examination>();

        ResultSet resultSet = statement.executeQuery();
        while (resultSet.next()) {
            results.add(new Examination(resultSet.getInt("doctor_id"), resultSet.getInt("admission_id"), resultSet.getString("comment_text")));
        }

        return results;
    }
}

/* Models */

class Stay {
    public int admissionId;
    public String roomNumber;
    public Date startDate;
    public Date endDate;

    public Stay(int admissionId, String roomNumber, Date startDate, Date endDate) {
        this.admissionId = admissionId;
        this.roomNumber = roomNumber;
        this.startDate = startDate;
        this.endDate = endDate;
    }
}

class Patient {
    public String ssn;
    public String firstName;
    public String lastName;
    public String address;
    public String phone;

    public Patient(String ssn, String firstName, String lastName, String address, String phone) {
        this.ssn = ssn;
        this.firstName = firstName;
        this.lastName = lastName;
        this.address = address;
        this.phone = phone;
    }
}

class Examination {
    public int doctorId;
    public int admissionId;
    public String commentText;

    public Examination(int doctorId, int admissionId, String commentText) {
        this.doctorId = doctorId;
        this.admissionId = admissionId;
        this.commentText = commentText;
    }
}

class Doctor {
    public int id;
    public Gender gender;
    public String specialty;
    public String firstName;
    public String lastName;

    public Doctor(int id, Gender gender, String specialty, String firstName, String lastName) {
        this.id = id;
        this.gender = gender;
        this.specialty = specialty;
        this.firstName = firstName;
        this.lastName = lastName;
    }

    public enum Gender {
        FEMALE,
        MALE;

        public static Gender fromInt(int val) {
            switch (val) {
                case 0: return FEMALE;
                case 1: return MALE;
                default: return null;
            }
        }

        public String toString() {
            switch (this) {
                case FEMALE: return "Female";
                case MALE: return "Male";
            }

            return null;
        }
    }
}

class Admission {
    public int id;
    public String patientSSN;
    public Date admitDate;
    public Date leaveDate;
    public double totalPayment;
    public double insurancePayment;
    public Date futureVisitDate;

    public Admission(int id, String patientSSN, Date admitDate, Date leaveDate, double totalPayment, double insurancePayment, Date futureVisitDate) {
        this.id = id;
        this.patientSSN = patientSSN;
        this.admitDate = admitDate;
        this.leaveDate = leaveDate;
        this.totalPayment = totalPayment;
        this.insurancePayment = insurancePayment;
        this.futureVisitDate = futureVisitDate;
    }
}

