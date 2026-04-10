// Find ALL users who could access the Experience Cloud site
// Check community member profiles

// 1. Find all User types in the org
AggregateResult[] userTypes = [
    SELECT Profile.Name pname, Profile.UserType utype, COUNT(Id) cnt
    FROM User WHERE IsActive = true
    GROUP BY Profile.Name, Profile.UserType
    ORDER BY Profile.UserType
];
for (AggregateResult ar : userTypes) {
    System.debug('Profile: ' + ar.get('pname') + ' | Type: ' + ar.get('utype') + ' | Count: ' + ar.get('cnt'));
}

// 2. Get the GamingTestController class
ApexClass ctrl = [SELECT Id FROM ApexClass WHERE Name = 'GamingTestController' LIMIT 1];

// 3. Find ALL profiles that DON'T have access
List<PermissionSet> allProfilePS = [
    SELECT Id, Name, ProfileId, Profile.Name, Profile.UserType
    FROM PermissionSet 
    WHERE IsOwnedByProfile = true AND ProfileId != null
];
System.debug('Total profile-based PS: ' + allProfilePS.size());

for (PermissionSet ps : allProfilePS) {
    List<SetupEntityAccess> sea = [
        SELECT Id FROM SetupEntityAccess 
        WHERE ParentId = :ps.Id AND SetupEntityId = :ctrl.Id
    ];
    if (sea.isEmpty()) {
        System.debug('NO ACCESS: ' + ps.Profile.Name + ' (' + ps.Profile.UserType + ')');
        // Grant access
        try {
            insert new SetupEntityAccess(ParentId = ps.Id, SetupEntityId = ctrl.Id);
            System.debug('  >>> GRANTED');
        } catch (Exception e) {
            System.debug('  >>> FAILED: ' + e.getMessage());
        }
    }
}

// 4. Also check custom permission sets (non-profile)
List<PermissionSet> customPS = [
    SELECT Id, Name, Label FROM PermissionSet 
    WHERE IsOwnedByProfile = false AND IsCustom = true
];
for (PermissionSet ps : customPS) {
    List<SetupEntityAccess> sea = [
        SELECT Id FROM SetupEntityAccess 
        WHERE ParentId = :ps.Id AND SetupEntityId = :ctrl.Id
    ];
    if (sea.isEmpty()) {
        System.debug('Custom PS without access: ' + ps.Name + ' (' + ps.Label + ')');
        try {
            insert new SetupEntityAccess(ParentId = ps.Id, SetupEntityId = ctrl.Id);
            System.debug('  >>> GRANTED');
        } catch (Exception e) {
            System.debug('  >>> FAILED: ' + e.getMessage());
        }
    }
}
