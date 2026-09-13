/// Formal professional job-title suggestions (Arabic / English).
/// Free-text jobTitle remains the source of truth; these are UX hints only.
List<String> formalJobTitleSuggestions({required bool isArabic}) {
  if (isArabic) {
    return const [
      'مدير عام',
      'مدير موارد بشرية',
      'أخصائي موارد بشرية',
      'أخصائي رواتب',
      'محاسب',
      'مدير مالي',
      'مدير تشغيل',
      'مشرف وردية',
      'مشرف موقع',
      'منسق إداري',
      'مسؤول حضور وانصراف',
      'أخصائي توظيف',
      'مدير فرع',
      'مساعد إداري',
      'مهندس صيانة',
      'مسؤول مخازن',
    ];
  }
  return const [
    'General Manager',
    'HR Director',
    'HR Specialist',
    'Payroll Specialist',
    'Accountant',
    'Finance Manager',
    'Operations Manager',
    'Shift Supervisor',
    'Site Supervisor',
    'Administrative Coordinator',
    'Attendance Officer',
    'Recruitment Specialist',
    'Branch Manager',
    'Administrative Assistant',
    'Maintenance Engineer',
    'Warehouse Officer',
  ];
}
