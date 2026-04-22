import asyncio
import os
from motor.motor_asyncio import AsyncIOMotorClient

# Fallback config if app context not available
MONGO_URI = os.getenv("MONGO_URI", "mongodb://localhost:27017")
DB_NAME = os.getenv("DB_NAME", "vitalguard")

HOSPITALS = [
    {
        "name": "Apollo Hospital",
        "lat": 12.9252,
        "lng": 77.6011,
        "specializations": ["Cardiology", "Trauma", "General"],
        "total_beds": 100,
        "available_beds": 85,
        "total_doctors": 30,
        "available_doctors": 12,
        "rating": 4.8,
        "doctors": [
            {"name": "Dr. Anirudh Kulkarni", "phone": "9880123456", "specialization": "Cardiology"},
            {"name": "Dr. Sarah D'souza", "phone": "9880654321", "specialization": "Trauma Care"},
            {"name": "Dr. Ramesh Babu", "phone": "9887766554", "specialization": "Internal Medicine"}
        ]
    },
    {
        "name": "Fortis Hospital",
        "lat": 12.9611,
        "lng": 77.6387,
        "specializations": ["Orthopedics", "General", "Trauma"],
        "total_beds": 80,
        "available_beds": 40,
        "total_doctors": 25,
        "available_doctors": 18,
        "rating": 4.5,
        "doctors": [
            {"name": "Dr. Kavita Nair", "phone": "9770112233", "specialization": "Orthopedics"},
            {"name": "Dr. Michael Chen", "phone": "9772233445", "specialization": "General Surgery"},
            {"name": "Dr. Priyanshu Jha", "phone": "9773344556", "specialization": "Emergency Medicine"}
        ]
    },
    {
        "name": "Manipal Hospital",
        "lat": 12.9591,
        "lng": 77.6473,
        "specializations": ["Neurology", "Pediatrics", "General"],
        "total_beds": 120,
        "available_beds": 110,
        "total_doctors": 40,
        "available_doctors": 35,
        "rating": 4.7,
        "doctors": [
            {"name": "Dr. Sumanth Shetty", "phone": "9661122334", "specialization": "Neurology"},
            {"name": "Dr. Deepa Rao", "phone": "9662233445", "specialization": "Pediatrics"},
            {"name": "Dr. Aditi Verma", "phone": "9663344556", "specialization": "General Physician"}
        ]
    },
    {
        "name": "Narayana Health",
        "lat": 12.8938,
        "lng": 77.5949,
        "specializations": ["Oncology", "Cardiology", "Cardiac Surgery"],
        "total_beds": 150,
        "available_beds": 10,
        "total_doctors": 50,
        "available_doctors": 5,
        "rating": 4.9,
        "doctors": [
            {"name": "Dr. AR Reddy", "phone": "9551122334", "specialization": "Oncology"},
            {"name": "Dr. Vikram Singh", "phone": "9552233445", "specialization": "Cardiac Surgery"},
            {"name": "Dr. Sneha Patil", "phone": "9553344556", "specialization": "Cardiology"}
        ]
    },
    {
        "name": "St. John's Hospital",
        "lat": 12.9353,
        "lng": 77.6174,
        "specializations": ["General", "Emergency Care", "Trauma"],
        "total_beds": 200,
        "available_beds": 150,
        "total_doctors": 60,
        "available_doctors": 40,
        "rating": 4.3,
        "doctors": [
            {"name": "Dr. John Doe", "phone": "9441122334", "specialization": "Emergency Medicine"},
            {"name": "Dr. Maria Garcia", "phone": "9442233445", "specialization": "Trauma Surgery"},
            {"name": "Dr. Rajesh Khanna", "phone": "9443344556", "specialization": "General Physician"}
        ]
    }
]

async def init_hospitals():
    client = AsyncIOMotorClient(MONGO_URI)
    db = client[DB_NAME]
    
    print(f"Connecting to {MONGO_URI}...")
    
    # Clear existing hospitals
    await db.hospitals.delete_many({})
    print("Cleared existing hospital data.")
    
    # Insert new data
    result = await db.hospitals.insert_many(HOSPITALS)
    print(f"Inserted {len(result.inserted_ids)} hospitals successfully.")
    
    client.close()

if __name__ == "__main__":
    asyncio.run(init_hospitals())
