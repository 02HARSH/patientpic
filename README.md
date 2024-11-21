
# PatienticPic Healthcare App

**PatienticPic Healthcare** is a Flutter-based application designed to streamline communication between patients and doctors. The app allows patients to document their medical conditions via images and receive tailored prescriptions from doctors.

---

## Features

### Patient Features:
- **Capture Images**: Use the camera to capture images of wounds or medical conditions.
- **Upload Images**: Choose images from the gallery to document medical conditions.
- **View Prescriptions**: Check prescriptions assigned by doctors for specific images.
- **Download Prescriptions**: Save prescriptions locally for offline access.

### Doctor Features:
- **Patient Folder Management**: View individual patient folders containing uploaded images.
- **Assign Prescriptions**:
    - Upload prescription files.
    - Capture images as prescriptions.
    - Write custom prescription notes.

---

## Installation and Setup

Follow these steps to set up and run the project:

### Step 1: Clone the Repository
Clone the project to your local machine:
git clone https://github.com/02HARSH/patientpic.git

### Step 2: Navigate to the Project Directory
Navigate to the project folder where the code is stored:
cd patientpic


### Step 3: Install Flutter Dependencies
Run the following command to fetch all the required dependencies:

flutter pub get
### Step 4: Configure Firebase

#### Create a Firebase Project:
1. Go to the Firebase Console.
2. Create a new Firebase project.

#### Add Your App:
1. Register your Android and iOS apps in Firebase.

#### Download Configuration Files:
- For Android: Download `google-services.json` and place it in the `android/app` folder.
- For iOS: Download `GoogleService-Info.plist` and place it in the `ios/Runner` folder.

#### Enable Firebase Features:
- Enable Authentication for email/password login.
- Set up Cloud Firestore for storing user data.
- Enable Firebase Storage for uploading and retrieving images.
### Step 5: Run the App
Use the following command to start the app on an emulator or a connected device:

flutter run
## Usage Instructions

### For Patients:
#### Register/Login:
- Register using your email and password, or log in with existing credentials.

#### Capture or Upload Images:
- Capture images via the camera or select them from the gallery.

#### View and Download Prescriptions:
- Access assigned prescriptions for your uploaded images.
- Download prescriptions to follow the doctor’s advice.

### For Doctors:
#### Register/Login:
- Register as a doctor (admin approval is required for access).

#### View Patient Folders:
- Access patient-specific folders containing uploaded images.

#### Assign Prescriptions:
For each patient image:
- Upload a file as a prescription.
- Capture a prescription image.
- Write a custom prescription note.
