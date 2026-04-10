// Grant guest user access to GamingTestController
// Find guest user profile
List<Profile> guestProfiles = [SELECT Id, Name FROM Profile WHERE Name LIKE '%Guest%' OR Name LIKE '%Invité%'];
System.debug('Guest profiles: ' + guestProfiles);

// Check current Apex class access for GamingTestController
// Query SetupEntityAccess for the class
List<ApexClass> classes = [SELECT Id, Name FROM ApexClass WHERE Name = 'GamingTestController'];
System.debug('GamingTestController class: ' + classes);

if (!classes.isEmpty()) {
    Id classId = classes[0].Id;
    List<SetupEntityAccess> accesses = [
        SELECT Id, ParentId, Parent.Name, SetupEntityId 
        FROM SetupEntityAccess 
        WHERE SetupEntityId = :classId
    ];
    System.debug('Current accesses for GamingTestController: ' + accesses.size());
    for (SetupEntityAccess a : accesses) {
        System.debug('  Access: ParentId=' + a.ParentId + ' Parent.Name=' + a.Parent.Name);
    }
}

// Also check for InternalDashboardController
List<ApexClass> intClasses = [SELECT Id, Name FROM ApexClass WHERE Name = 'InternalDashboardController'];
if (!intClasses.isEmpty()) {
    List<SetupEntityAccess> accesses2 = [
        SELECT Id, ParentId, Parent.Name
        FROM SetupEntityAccess 
        WHERE SetupEntityId = :intClasses[0].Id
    ];
    System.debug('InternalDashboardController accesses: ' + accesses2.size());
    for (SetupEntityAccess a : accesses2) {
        System.debug('  Access: ' + a.Parent.Name);
    }
}
