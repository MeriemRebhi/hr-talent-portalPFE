// Grant GamingTestController access to Customer Community Login User profile
ApexClass ctrl = [SELECT Id FROM ApexClass WHERE Name = 'GamingTestController' LIMIT 1];

// Find the CspLitePortal profile-owned permission set
List<PermissionSet> cspPS = [
    SELECT Id, Name, ProfileId, Profile.Name, Profile.UserType
    FROM PermissionSet 
    WHERE IsOwnedByProfile = true 
    AND Profile.UserType = 'CspLitePortal'
];
System.debug('CspLitePortal PS count: ' + cspPS.size());

for (PermissionSet ps : cspPS) {
    System.debug('PS: ' + ps.Id + ' | Profile: ' + ps.Profile.Name);
    List<SetupEntityAccess> sea = [SELECT Id FROM SetupEntityAccess WHERE ParentId = :ps.Id AND SetupEntityId = :ctrl.Id];
    System.debug('  Has access: ' + !sea.isEmpty());
    if (sea.isEmpty()) {
        try {
            insert new SetupEntityAccess(ParentId = ps.Id, SetupEntityId = ctrl.Id);
            System.debug('  >>> GRANTED!');
        } catch (Exception e) {
            System.debug('  >>> FAILED: ' + e.getMessage());
        }
    }
}

// Also try standard Community user types
List<PermissionSet> allCommunityPS = [
    SELECT Id, Name, ProfileId, Profile.Name, Profile.UserType
    FROM PermissionSet 
    WHERE IsOwnedByProfile = true 
    AND (Profile.UserType = 'CspLitePortal' 
         OR Profile.UserType = 'PowerCustomerSuccess'
         OR Profile.UserType = 'CustomerSuccess'
         OR Profile.UserType = 'PowerPartner'
         OR Profile.Name LIKE '%Community%'
         OR Profile.Name LIKE '%Portal%'
         OR Profile.Name LIKE '%Experience%')
];
System.debug('All community-related PS: ' + allCommunityPS.size());

for (PermissionSet ps : allCommunityPS) {
    List<SetupEntityAccess> sea = [SELECT Id FROM SetupEntityAccess WHERE ParentId = :ps.Id AND SetupEntityId = :ctrl.Id];
    if (sea.isEmpty()) {
        try {
            insert new SetupEntityAccess(ParentId = ps.Id, SetupEntityId = ctrl.Id);
            System.debug('GRANTED: ' + ps.Profile.Name + ' (' + ps.Profile.UserType + ')');
        } catch (Exception e) {
            System.debug('FAILED: ' + ps.Profile.Name + ' -> ' + e.getMessage());
        }
    } else {
        System.debug('ALREADY: ' + ps.Profile.Name);
    }
}

// List the community users to confirm their profile
List<User> communityUsers = [SELECT Id, Name, ProfileId, Profile.Name, Profile.UserType FROM User WHERE Profile.UserType IN ('CspLitePortal','PowerCustomerSuccess','CustomerSuccess') AND IsActive = true LIMIT 10];
for (User u : communityUsers) {
    System.debug('Community User: ' + u.Name + ' | Profile: ' + u.Profile.Name + ' | Type: ' + u.Profile.UserType);
}
