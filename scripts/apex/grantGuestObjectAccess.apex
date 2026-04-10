// Grant Guest User CRUD on Password_Reset_Token__c and Security_Audit_Log__c
String profileId = '00efj000008OTBdAAO';
PermissionSet profPS = [SELECT Id FROM PermissionSet WHERE ProfileId = :profileId AND IsOwnedByProfile = true LIMIT 1];

// Grant object permissions for Password_Reset_Token__c
List<ObjectPermissions> existingPRT = [
    SELECT Id FROM ObjectPermissions 
    WHERE ParentId = :profPS.Id AND SobjectType = 'Password_Reset_Token__c'
];
if (existingPRT.isEmpty()) {
    ObjectPermissions opPRT = new ObjectPermissions();
    opPRT.ParentId = profPS.Id;
    opPRT.SobjectType = 'Password_Reset_Token__c';
    opPRT.PermissionsRead = true;
    opPRT.PermissionsCreate = true;
    opPRT.PermissionsEdit = true;
    opPRT.PermissionsDelete = true;
    insert opPRT;
    System.debug('GRANTED CRUD on Password_Reset_Token__c');
} else {
    System.debug('Already has permissions on Password_Reset_Token__c');
}

// Grant object permissions for Security_Audit_Log__c
List<ObjectPermissions> existingSAL = [
    SELECT Id FROM ObjectPermissions 
    WHERE ParentId = :profPS.Id AND SobjectType = 'Security_Audit_Log__c'
];
if (existingSAL.isEmpty()) {
    ObjectPermissions opSAL = new ObjectPermissions();
    opSAL.ParentId = profPS.Id;
    opSAL.SobjectType = 'Security_Audit_Log__c';
    opSAL.PermissionsRead = true;
    opSAL.PermissionsCreate = true;
    opSAL.PermissionsEdit = true;
    opSAL.PermissionsDelete = false;
    insert opSAL;
    System.debug('GRANTED CRU on Security_Audit_Log__c');
} else {
    System.debug('Already has permissions on Security_Audit_Log__c');
}

System.debug('DONE - Guest user can now CRUD Password_Reset_Token__c and Security_Audit_Log__c');
