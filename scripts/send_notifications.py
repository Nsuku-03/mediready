import json
import os
import firebase_admin
from firebase_admin import credentials, firestore, messaging


# Connect securely to Firebase using the GitHub secret
service_account_info = json.loads(
    os.environ["FIREBASE_SERVICE_ACCOUNT"]
)

credentials_object = credentials.Certificate(service_account_info)

firebase_admin.initialize_app(credentials_object)

db = firestore.client()


def send_pending_notifications():
    print("MediReady: Checking for pending notifications...")

    medications = (
        db.collection("medications")
        .where("notificationPending", "==", True)
        .stream()
    )

    for medication in medications:
        medication_data = medication.to_dict()

        patient_id = medication_data.get("patientId")
        medication_name = medication_data.get(
            "medicationName", "your medication"
        )
        status = medication_data.get("status", "updated")

        if not patient_id:
            print(f"Missing patient ID for {medication.id}")
            continue

        patient = db.collection("patients").document(patient_id).get()

        if not patient.exists:
            print(f"Patient not found: {patient_id}")
            continue

        patient_data = patient.to_dict()
        token = patient_data.get("fcmToken")

        if not token:
            print(f"No notification token for patient {patient_id}")
            continue

        message = messaging.Message(
            notification=messaging.Notification(
                title="MediReady medication update",
                body=f"Your {medication_name} is now {status}.",
            ),
            data={
                "medicationId": medication.id,
                "status": str(status),
            },
            token=token,
            android=messaging.AndroidConfig(priority="high"),
        )

        try:
            response = messaging.send(message)

            medication.reference.update({
                "notificationPending": False,
                "notificationSent": True,
                "notificationSentAt": firestore.SERVER_TIMESTAMP,
                "notificationError": firestore.DELETE_FIELD,
            })

            print(
                f"Notification sent for {medication.id}: {response}"
            )

        except Exception as error:
            medication.reference.update({
                "notificationError": str(error),
            })

            print(
                f"Notification failed for {medication.id}: {error}"
            )


if __name__ == "__main__":
    send_pending_notifications()
