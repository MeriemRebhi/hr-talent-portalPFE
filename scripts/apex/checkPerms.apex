// Check and grant object permissions for Standard User profile
User ahmed = [SELECT Id, ProfileId FROM User WHERE Username = 'ahmed.bensalah.pfe@talan-tunisie.dev' LIMIT 1];

// Check if the profile has read access to Opportunity
List<ObjectPermissions> objPerms = [
    SELECT SObjectType, PermissionsRead, PermissionsCreate, PermissionsEdit
    FROM ObjectPermissions
    WHERE ParentId IN (SELECT Id FROM PermissionSet WHERE ProfileId = :ahmed.ProfileId AND IsOwnedByProfile = true)
    AND SObjectType = 'Opportunity'
];
for (ObjectPermissions op : objPerms) {
    System.debug('Opportunity perms: Read=' + op.PermissionsRead + ' Create=' + op.PermissionsCreate + ' Edit=' + op.PermissionsEdit);
}

// Check Lead access
List<ObjectPermissions> leadPerms = [
    SELECT SObjectType, PermissionsRead
    FROM ObjectPermissions
    WHERE ParentId IN (SELECT Id FROM PermissionSet WHERE ProfileId = :ahmed.ProfileId AND IsOwnedByProfile = true)
    AND SObjectType = 'Lead'
];
for (ObjectPermissions op : leadPerms) {
    System.debug('Lead perms: Read=' + op.PermissionsRead);
}

// Check Technical_Interview__c access via permission set
List<PermissionSetAssignment> psas = [
    SELECT PermissionSet.Name FROM PermissionSetAssignment
    WHERE AssigneeId = :ahmed.Id
];
for (PermissionSetAssignment psa : psas) {
    System.debug('PermSet assigned: ' + psa.PermissionSet.Name);
}
