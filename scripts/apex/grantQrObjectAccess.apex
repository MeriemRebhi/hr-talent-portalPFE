// Check and grant Guest User access to QrLogin__c object
// The Guest user needs Create and Read access for token generation and validation

// Find the Guest User profile PermissionSet
List<PermissionSet> guestPS = [
    SELECT Id, Name, ProfileId, Profile.Name
    FROM PermissionSet
    WHERE IsOwnedByProfile = true
    AND Profile.Name = 'Talan Talent Intelligence RH2 Profile'
];

System.debug('Found ' + guestPS.size() + ' guest permission sets');

for (PermissionSet ps : guestPS) {
    // Check existing object permissions for QrLogin__c
    List<ObjectPermissions> objPerms = [
        SELECT Id, PermissionsCreate, PermissionsRead, PermissionsEdit
        FROM ObjectPermissions
        WHERE ParentId = :ps.Id
        AND SobjectType = 'QrLogin__c'
    ];
    
    if (objPerms.isEmpty()) {
        // Grant Create, Read, Edit
        ObjectPermissions op = new ObjectPermissions(
            ParentId = ps.Id,
            SobjectType = 'QrLogin__c',
            PermissionsCreate = true,
            PermissionsRead = true,
            PermissionsEdit = true,
            PermissionsDelete = false,
            PermissionsViewAllRecords = false,
            PermissionsModifyAllRecords = false
        );
        insert op;
        System.debug('QrLogin__c object permissions GRANTED for Guest');
    } else {
        ObjectPermissions op = objPerms[0];
        System.debug('QrLogin__c permissions exist: Create=' + op.PermissionsCreate + ', Read=' + op.PermissionsRead + ', Edit=' + op.PermissionsEdit);
        // Ensure Create and Edit are enabled
        if (!op.PermissionsCreate || !op.PermissionsRead || !op.PermissionsEdit) {
            op.PermissionsCreate = true;
            op.PermissionsRead = true;
            op.PermissionsEdit = true;
            update op;
            System.debug('QrLogin__c permissions UPDATED for Guest');
        }
    }
}

// Also for Customer Community Login User
List<PermissionSet> cclPS = [
    SELECT Id, ProfileId, Profile.Name
    FROM PermissionSet
    WHERE IsOwnedByProfile = true
    AND Profile.Name = 'Customer Community Login User'
];

for (PermissionSet ps : cclPS) {
    List<ObjectPermissions> objPerms = [
        SELECT Id, PermissionsCreate, PermissionsRead, PermissionsEdit
        FROM ObjectPermissions
        WHERE ParentId = :ps.Id
        AND SobjectType = 'QrLogin__c'
    ];
    
    if (objPerms.isEmpty()) {
        ObjectPermissions op = new ObjectPermissions(
            ParentId = ps.Id,
            SobjectType = 'QrLogin__c',
            PermissionsCreate = true,
            PermissionsRead = true,
            PermissionsEdit = true,
            PermissionsDelete = false,
            PermissionsViewAllRecords = false,
            PermissionsModifyAllRecords = false
        );
        insert op;
        System.debug('QrLogin__c object permissions GRANTED for CCL');
    } else {
        System.debug('QrLogin__c permissions already exist for CCL');
    }
}

System.debug('QrLogin__c object access check complete');
