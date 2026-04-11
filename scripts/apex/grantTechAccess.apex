// Grant guest user access to Technical Interview Apex classes
String profileId = '00efj000008OTBdAAO'; // Talan Talent Intelligence RH2 Profile

List<ApexClass> classes = [
    SELECT Id, Name FROM ApexClass 
    WHERE Name IN ('TechnicalInterviewController', 'TechnicalQuestionService')
];

System.debug('Found ' + classes.size() + ' Apex classes');

PermissionSet profPS = [SELECT Id FROM PermissionSet WHERE ProfileId = :profileId AND IsOwnedByProfile = true LIMIT 1];

for (ApexClass cls : classes) {
    List<SetupEntityAccess> existing = [
        SELECT Id FROM SetupEntityAccess 
        WHERE SetupEntityId = :cls.Id 
        AND ParentId = :profPS.Id
    ];
    
    if (existing.isEmpty()) {
        SetupEntityAccess sea = new SetupEntityAccess();
        sea.ParentId = profPS.Id;
        sea.SetupEntityId = cls.Id;
        insert sea;
        System.debug('✅ Granted access to: ' + cls.Name);
    } else {
        System.debug('Already has access to: ' + cls.Name);
    }
}

System.debug('DONE - Guest can call TechnicalInterviewController + TechnicalQuestionService');
