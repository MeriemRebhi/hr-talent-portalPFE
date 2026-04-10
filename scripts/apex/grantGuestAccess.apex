// Grant Guest User profile access to Opportunity object and key fields
// This script gives the guest profile read access via a Permission Set

// Find the guest user profile for home2 site
Profile guestProfile = [SELECT Id, Name FROM Profile WHERE Name = 'Talan Talent Intelligence RH2 Profile' LIMIT 1];
System.debug('Guest Profile: ' + guestProfile.Name + ' (' + guestProfile.Id + ')');

// Check existing permission sets for guest
List<PermissionSet> existingPS = [SELECT Id, Name FROM PermissionSet WHERE Name = 'Guest_Job_Viewer'];
if (!existingPS.isEmpty()) {
    delete existingPS;
    System.debug('Deleted old Permission Set');
}

// Create Permission Set
PermissionSet ps = new PermissionSet();
ps.Name = 'Guest_Job_Viewer';
ps.Label = 'Guest Job Viewer';
insert ps;
System.debug('Created PermissionSet: ' + ps.Id);

// Add Object permissions for Opportunity (Read)
ObjectPermissions objPerm = new ObjectPermissions();
objPerm.ParentId = ps.Id;
objPerm.SobjectType = 'Opportunity';
objPerm.PermissionsRead = true;
insert objPerm;
System.debug('Added Opportunity Read');

// Add Field permissions
List<FieldPermissions> fieldPerms = new List<FieldPermissions>();
List<String> fields = new List<String>{
    'Opportunity.Localisation__c',
    'Opportunity.Type_de_Contrat__c',
    'Opportunity.Salaire_Propos__c',
    'Opportunity.Description_Poste__c',
    'Opportunity.Departement__c'
};
for (String f : fields) {
    FieldPermissions fp = new FieldPermissions();
    fp.ParentId = ps.Id;
    fp.SobjectType = 'Opportunity';
    fp.Field = f;
    fp.PermissionsRead = true;
    fp.PermissionsEdit = false;
    fieldPerms.add(fp);
}
insert fieldPerms;
System.debug('Added ' + fieldPerms.size() + ' field permissions');

// Assign to Guest User
User guestUser = [SELECT Id FROM User WHERE Name LIKE '%RH2 Site Guest%' AND IsActive = true LIMIT 1];
PermissionSetAssignment psa = new PermissionSetAssignment();
psa.PermissionSetId = ps.Id;
psa.AssigneeId = guestUser.Id;
insert psa;
System.debug('Assigned to Guest User: ' + guestUser.Id);
System.debug('DONE - Guest can now view Job Postings!');
