// Grant Apex class access to Ahmed and Sami via their profile's permission set
User ahmed = [SELECT Id, ProfileId FROM User WHERE Username = 'ahmed.bensalah.pfe@talan-tunisie.dev' LIMIT 1];
User sami  = [SELECT Id, ProfileId FROM User WHERE Username = 'sami.trabelsi.pfe@talan-tunisie.dev' LIMIT 1];

System.debug('Ahmed ProfileId: ' + ahmed.ProfileId);
System.debug('Sami ProfileId: ' + sami.ProfileId);

// Get profile-based permission set for Standard User
PermissionSet stdPS = [SELECT Id FROM PermissionSet WHERE ProfileId = :ahmed.ProfileId AND IsOwnedByProfile = true LIMIT 1];
System.debug('Standard User PermSet: ' + stdPS.Id);

// Find all our custom Apex classes
List<ApexClass> classes = [
    SELECT Id, Name FROM ApexClass
    WHERE Name IN (
        'InternalDashboardController',
        'TechnicalInterviewController',
        'TechnicalQuestionService',
        'CVScoringService',
        'GamingQuestionService'
    )
];
System.debug('Found classes: ' + classes.size());

// Check existing access
Set<Id> existingClassIds = new Set<Id>();
for (SetupEntityAccess sea : [
    SELECT SetupEntityId FROM SetupEntityAccess
    WHERE ParentId = :stdPS.Id AND SetupEntityType = 'ApexClass'
]) {
    existingClassIds.add(sea.SetupEntityId);
}

// Add missing access
List<SetupEntityAccess> toInsert = new List<SetupEntityAccess>();
for (ApexClass cls : classes) {
    if (!existingClassIds.contains(cls.Id)) {
        toInsert.add(new SetupEntityAccess(
            ParentId = stdPS.Id,
            SetupEntityId = cls.Id
        ));
        System.debug('→ Granting access to: ' + cls.Name);
    } else {
        System.debug('✓ Already has access: ' + cls.Name);
    }
}

if (!toInsert.isEmpty()) {
    insert toInsert;
    System.debug('✅ ' + toInsert.size() + ' Apex classes granted to Standard User profile');
} else {
    System.debug('✅ All classes already accessible');
}
