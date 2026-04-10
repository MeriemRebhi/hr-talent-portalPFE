// Publish the Experience Cloud site to refresh cache
// Find the Talan Talent Intelligence RH2 network (home2)
List<Network> networks = [SELECT Id, Name, Status FROM Network WHERE Status = 'Live'];
for (Network n : networks) {
    System.debug('Network: ' + n.Name + ' | Id: ' + n.Id);
}

// Re-grant access after redeploy (the class ID may have changed)
ApexClass ctrl = [SELECT Id FROM ApexClass WHERE Name = 'GamingTestController' LIMIT 1];
System.debug('GamingTestController new Id: ' + ctrl.Id);

// Make sure the specific guest profile still has access
List<PermissionSet> guestPS = [
    SELECT Id, Name, ProfileId, Profile.Name
    FROM PermissionSet 
    WHERE IsOwnedByProfile = true 
    AND Profile.Name = 'Talan Talent Intelligence RH2 Profile'
];
for (PermissionSet ps : guestPS) {
    List<SetupEntityAccess> sea = [SELECT Id FROM SetupEntityAccess WHERE ParentId = :ps.Id AND SetupEntityId = :ctrl.Id];
    System.debug('Talan RH2 guest access: ' + !sea.isEmpty());
    if (sea.isEmpty()) {
        insert new SetupEntityAccess(ParentId = ps.Id, SetupEntityId = ctrl.Id);
        System.debug('  >>> RE-GRANTED');
    }
}

// Check Customer Community Login User
List<PermissionSet> cclPS = [
    SELECT Id, ProfileId, Profile.Name
    FROM PermissionSet 
    WHERE IsOwnedByProfile = true 
    AND Profile.Name = 'Customer Community Login User'
];
for (PermissionSet ps : cclPS) {
    List<SetupEntityAccess> sea = [SELECT Id FROM SetupEntityAccess WHERE ParentId = :ps.Id AND SetupEntityId = :ctrl.Id];
    System.debug('Customer Community Login User access: ' + !sea.isEmpty());
    if (sea.isEmpty()) {
        insert new SetupEntityAccess(ParentId = ps.Id, SetupEntityId = ctrl.Id);
        System.debug('  >>> RE-GRANTED');
    }
}

// Publish via SF CLI instead
System.debug('Use sf community publish command to publish the site');
System.debug('All access checks completed');
