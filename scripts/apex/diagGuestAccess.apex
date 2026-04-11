// Check Guest User Apex access for TechnicalInterviewController
Id guestProfileId = '00efj000008OTBdAAO';

// Check if guest profile can access TechnicalInterviewController
List<SetupEntityAccess> access = [
    SELECT Id, SetupEntityId, SetupEntityType, ParentId, Parent.Name
    FROM SetupEntityAccess
    WHERE SetupEntityType = 'ApexClass'
    AND Parent.ProfileId = :guestProfileId
];
System.debug('Guest Apex access grants: ' + access.size());
for (SetupEntityAccess sea : access) {
    System.debug('  class: ' + sea.SetupEntityId + ' via: ' + sea.Parent.Name);
}

// Find the TechnicalInterviewController class ID
List<ApexClass> cls = [SELECT Id, Name FROM ApexClass WHERE Name = 'TechnicalInterviewController'];
if (!cls.isEmpty()) {
    System.debug('TechnicalInterviewController ID: ' + cls[0].Id);
    // Check if this specific class is accessible
    Boolean hasAccess = false;
    for (SetupEntityAccess sea : access) {
        if (sea.SetupEntityId == cls[0].Id) {
            hasAccess = true;
            break;
        }
    }
    System.debug('Guest has access to TechnicalInterviewController: ' + hasAccess);
}

// Also check TechnicalQuestionService
List<ApexClass> cls2 = [SELECT Id, Name FROM ApexClass WHERE Name = 'TechnicalQuestionService'];
if (!cls2.isEmpty()) {
    System.debug('TechnicalQuestionService ID: ' + cls2[0].Id);
    Boolean hasAccess2 = false;
    for (SetupEntityAccess sea : access) {
        if (sea.SetupEntityId == cls2[0].Id) {
            hasAccess2 = true;
            break;
        }
    }
    System.debug('Guest has access to TechnicalQuestionService: ' + hasAccess2);
}

// Check the LWC page route
System.debug('Expected URL: /home2/s/entretientechnique?id=...');
System.debug('Note: Experience page route is case-sensitive!');
