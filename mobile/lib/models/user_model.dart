class UserModel {
  final String uid, email, fullName, bloodGroup;
  final int age;
  final String emergencyContactName, emergencyContactPhone;
  final String? emergencyContactRelation, doctorName, doctorPhone, doctorHospital;

  UserModel({required this.uid, required this.email, required this.fullName,
    required this.bloodGroup, required this.age,
    required this.emergencyContactName, required this.emergencyContactPhone,
    this.emergencyContactRelation, this.doctorName, this.doctorPhone, this.doctorHospital});

  Map<String, dynamic> toJson() => {
    'uid':uid,'email':email,'full_name':fullName,'blood_group':bloodGroup,'age':age,
    'emergency_contact_name':emergencyContactName,'emergency_contact_phone':emergencyContactPhone,
    if(emergencyContactRelation!=null)'emergency_contact_relation':emergencyContactRelation,
    if(doctorName!=null)'doctor_name':doctorName,
    if(doctorPhone!=null)'doctor_phone':doctorPhone,
    if(doctorHospital!=null)'doctor_hospital':doctorHospital,
  };
}
