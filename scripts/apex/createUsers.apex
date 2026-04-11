// ═══════════════════════════════════════
// Créer 2 utilisateurs : Recruteur Java + Manager Technique
// ═══════════════════════════════════════

// Get the Standard User profile
Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
System.debug('Profile Standard User: ' + stdProfile.Id);

// Get the System Administrator profile for the manager
Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
System.debug('Profile Admin: ' + adminProfile.Id);

// ── Recruteur Java / Data & AI ──
User recruteurJava = new User(
    FirstName      = 'Ahmed',
    LastName       = 'Ben Salah',
    Email          = 'ahmed.bensalah.pfe@talan.com',
    Username       = 'ahmed.bensalah.pfe@talan-tunisie.dev',
    Alias          = 'absalah',
    ProfileId      = stdProfile.Id,
    EmailEncodingKey = 'UTF-8',
    LanguageLocaleKey = 'fr',
    LocaleSidKey   = 'fr_FR',
    TimeZoneSidKey = 'Europe/Paris',
    IsActive       = true
);
insert recruteurJava;
System.debug('✅ Recruteur Java créé: ' + recruteurJava.Id + ' — ' + recruteurJava.Username);

// ── Manager Technique ──
User managerTech = new User(
    FirstName      = 'Sami',
    LastName       = 'Trabelsi',
    Email          = 'sami.trabelsi.pfe@talan.com',
    Username       = 'sami.trabelsi.pfe@talan-tunisie.dev',
    Alias          = 'strab',
    ProfileId      = stdProfile.Id,
    EmailEncodingKey = 'UTF-8',
    LanguageLocaleKey = 'fr',
    LocaleSidKey   = 'fr_FR',
    TimeZoneSidKey = 'Europe/Paris',
    IsActive       = true
);
insert managerTech;
System.debug('✅ Manager Technique créé: ' + managerTech.Id + ' — ' + managerTech.Username);

// ── Assign permission set for access to custom objects ──
PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Security_Objects_Full_Access' LIMIT 1];
if (ps != null) {
    List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
    assignments.add(new PermissionSetAssignment(AssigneeId = recruteurJava.Id, PermissionSetId = ps.Id));
    assignments.add(new PermissionSetAssignment(AssigneeId = managerTech.Id, PermissionSetId = ps.Id));
    insert assignments;
    System.debug('✅ Permission Set assigné aux 2 utilisateurs');
}

System.debug('');
System.debug('════════════════════════════════════════════');
System.debug('  RÉSUMÉ DES UTILISATEURS CRÉÉS');
System.debug('════════════════════════════════════════════');
System.debug('  1. Ahmed Ben Salah (Recruteur Java/Data)');
System.debug('     Username: ahmed.bensalah.pfe@talan-tunisie.dev');
System.debug('     Email: ahmed.bensalah.pfe@talan.com');
System.debug('');
System.debug('  2. Sami Trabelsi (Manager Technique)');
System.debug('     Username: sami.trabelsi.pfe@talan-tunisie.dev');
System.debug('     Email: sami.trabelsi.pfe@talan.com');
System.debug('════════════════════════════════════════════');
