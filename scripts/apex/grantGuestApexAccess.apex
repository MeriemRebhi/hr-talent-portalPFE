// Grant Apex Class access to Guest User Profile
// The Guest User needs access to JobPostingController and ApplicationController

String profileId = '00efj000008OTBdAAO'; // Talan Talent Intelligence RH2 Profile

// Get Apex classes to grant
List<ApexClass> classes = [
    SELECT Id, Name FROM ApexClass 
    WHERE Name IN ('JobPostingController', 'ApplicationController', 'QrLoginController', 'RegistrationController', 'CustomPasswordResetController')
];

System.debug('Found ' + classes.size() + ' Apex classes');

for (ApexClass cls : classes) {
    // Check if already exists
    List<SetupEntityAccess> existing = [
        SELECT Id FROM SetupEntityAccess 
        WHERE SetupEntityId = :cls.Id 
        AND ParentId IN (SELECT Id FROM PermissionSet WHERE ProfileId = :profileId)
    ];
    
    if (existing.isEmpty()) {
        // Find the profile's permission set
        PermissionSet profPS = [SELECT Id FROM PermissionSet WHERE ProfileId = :profileId AND IsOwnedByProfile = true LIMIT 1];
        
        SetupEntityAccess sea = new SetupEntityAccess();
        sea.ParentId = profPS.Id;
        sea.SetupEntityId = cls.Id;
        insert sea;
        System.debug('Granted access to: ' + cls.Name);
    } else {
        System.debug('Already has access to: ' + cls.Name);
    }
}

System.debug('DONE - Guest profile can now call all Apex controllers!');
