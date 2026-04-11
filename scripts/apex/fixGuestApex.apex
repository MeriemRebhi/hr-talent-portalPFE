// Re-grant TechnicalInterviewController access to Guest User profile
Id guestProfileId = '00efj000008OTBdAAO';
Id classId = [SELECT Id FROM ApexClass WHERE Name = 'TechnicalInterviewController' LIMIT 1].Id;
Id serviceId = [SELECT Id FROM ApexClass WHERE Name = 'TechnicalQuestionService' LIMIT 1].Id;

// Get profile-based permission set
PermissionSet ps = [SELECT Id FROM PermissionSet WHERE ProfileId = :guestProfileId AND IsOwnedByProfile = true LIMIT 1];
System.debug('PermissionSet ID: ' + ps.Id);
System.debug('Class ID: ' + classId);
System.debug('Service ID: ' + serviceId);

// Delete existing access for these classes
List<SetupEntityAccess> existing = [
    SELECT Id, SetupEntityId FROM SetupEntityAccess 
    WHERE ParentId = :ps.Id 
    AND SetupEntityType = 'ApexClass' 
    AND SetupEntityId IN (:classId, :serviceId)
];
System.debug('Existing access records: ' + existing.size());
if (!existing.isEmpty()) {
    delete existing;
    System.debug('Deleted old access records');
}

// Re-insert access
List<SetupEntityAccess> newAccess = new List<SetupEntityAccess>();
newAccess.add(new SetupEntityAccess(
    ParentId = ps.Id,
    SetupEntityId = classId
));
newAccess.add(new SetupEntityAccess(
    ParentId = ps.Id,
    SetupEntityId = serviceId
));
insert newAccess;
System.debug('SUCCESS: Re-granted access to TechnicalInterviewController and TechnicalQuestionService');
