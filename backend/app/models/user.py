from pydantic import BaseModel
from typing import Optional, List

class FamilyMember(BaseModel):
    name: str
    phone: str
    relationship: str

class UserProfile(BaseModel):
    uid: str
    email: str
    full_name: str
    blood_group: str
    age: int
    emergency_contact_name: str
    emergency_contact_phone: str
    emergency_contact_relation: Optional[str] = None
    family_members: List[FamilyMember] = []
    doctor_name:    Optional[str] = None
    doctor_phone:   Optional[str] = None
    doctor_hospital:Optional[str] = None
    fcm_token:      Optional[str] = None
    location:       Optional[dict] = None

class UserProfileUpdate(BaseModel):
    full_name:    Optional[str] = None
    blood_group:  Optional[str] = None
    age:          Optional[int] = None
    emergency_contact_name:     Optional[str] = None
    emergency_contact_phone:    Optional[str] = None
    emergency_contact_relation: Optional[str] = None
    family_members: Optional[List[FamilyMember]] = None
    doctor_name:    Optional[str] = None
    doctor_phone:   Optional[str] = None
    doctor_hospital:Optional[str] = None
    fcm_token:      Optional[str] = None
    location:       Optional[dict] = None
