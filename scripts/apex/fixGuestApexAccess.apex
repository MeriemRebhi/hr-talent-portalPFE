// Grant Guest User access to TechnicalInterviewController and TechnicalQuestionService
// Guest User Profile ID: 00efj000008OTBdAAO (Talan Talent Intelligence RH2 Profile)

List<SetupEntityAccess> existing = [
    SELECT Id, SetupEntityId, ParentId 
    FROM SetupEntityAccess 
    WHERE Parent.ProfileId = '00efj000008OTBdAAO'
    AND SetupEntityType = 'ApexClass'
];
System.debug('Existing Apex access grants: ' + existing.size());
for (SetupEntityAccess sea : existing) {
    System.debug('  EntityId: ' + sea.SetupEntityId);
}

// Get the Apex class IDs
List<ApexClass> classes = [SELECT Id, Name FROM ApexClass WHERE Name IN ('TechnicalInterviewController', 'TechnicalQuestionService')];
System.debug('Found classes: ');
for (ApexClass c : classes) {
    System.debug('  ' + c.Name + ' => ' + c.Id);
}

// Get the permission set linked to the guest user profile
List<PermissionSet> guestPS = [SELECT Id, Name, ProfileId FROM PermissionSet WHERE ProfileId = '00efj000008OTBdAAO'];
System.debug('Guest PermissionSets: ' + guestPS.size());
for (PermissionSet ps : guestPS) {
    System.debug('  PS: ' + ps.Id + ' | ' + ps.Name);
}

if (!guestPS.isEmpty() && !classes.isEmpty()) {
    // Check which classes already have access
    Set<Id> classIds = new Set<Id>();
    for (ApexClass c : classes) classIds.add(c.Id);
    
    List<SetupEntityAccess> alreadyGranted = [
        SELECT SetupEntityId FROM SetupEntityAccess 
        WHERE ParentId = :guestPS[0].Id AND SetupEntityId IN :classIds
    ];
    Set<Id> grantedIds = new Set<Id>();
    for (SetupEntityAccess sea : alreadyGranted) grantedIds.add(sea.SetupEntityId);
    
    List<SetupEntityAccess> toInsert = new List<SetupEntityAccess>();
    for (ApexClass c : classes) {
        if (!grantedIds.contains(c.Id)) {
            toInsert.add(new SetupEntityAccess(
                ParentId = guestPS[0].Id,
                SetupEntityId = c.Id
            ));
            System.debug('Will grant access to: ' + c.Name);
        } else {
            System.debug('Already has access to: ' + c.Name);
        }
    }
    
    if (!toInsert.isEmpty()) {
        insert toInsert;
        System.debug('SUCCESS: Granted access to ' + toInsert.size() + ' classes');
    } else {
        System.debug('All classes already have access granted');
    }
}
