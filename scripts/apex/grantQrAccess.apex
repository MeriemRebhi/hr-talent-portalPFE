// Grant Guest profile access to QrLoginController for QR code generation
ApexClass qrCtrl = [SELECT Id FROM ApexClass WHERE Name = 'QrLoginController' LIMIT 1];
System.debug('QrLoginController Id: ' + qrCtrl.Id);

// Guest profile for the community site
List<PermissionSet> guestPS = [
    SELECT Id, Name, ProfileId, Profile.Name
    FROM PermissionSet
    WHERE IsOwnedByProfile = true
    AND Profile.Name = 'Talan Talent Intelligence RH2 Profile'
];
for (PermissionSet ps : guestPS) {
    List<SetupEntityAccess> sea = [SELECT Id FROM SetupEntityAccess WHERE ParentId = :ps.Id AND SetupEntityId = :qrCtrl.Id];
    System.debug('Guest access to QrLoginController: ' + !sea.isEmpty());
    if (sea.isEmpty()) {
        insert new SetupEntityAccess(ParentId = ps.Id, SetupEntityId = qrCtrl.Id);
        System.debug('  >>> GRANTED');
    }
}

// Also check Customer Community Login User profile
List<PermissionSet> cclPS = [
    SELECT Id, ProfileId, Profile.Name
    FROM PermissionSet
    WHERE IsOwnedByProfile = true
    AND Profile.Name = 'Customer Community Login User'
];
for (PermissionSet ps : cclPS) {
    List<SetupEntityAccess> sea = [SELECT Id FROM SetupEntityAccess WHERE ParentId = :ps.Id AND SetupEntityId = :qrCtrl.Id];
    System.debug('CCL access to QrLoginController: ' + !sea.isEmpty());
    if (sea.isEmpty()) {
        insert new SetupEntityAccess(ParentId = ps.Id, SetupEntityId = qrCtrl.Id);
        System.debug('  >>> GRANTED');
    }
}

System.debug('QrLoginController access check complete');
