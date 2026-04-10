// Grant Gaming classes access to Guest Profile  
String profileId = '00efj000008OTBdAAO';  
List<ApexClass> classes = [SELECT Id, Name FROM ApexClass WHERE Name IN ('GamingTestController', 'GamingQuestionService')];  
System.debug('Found ' + classes.size() + ' classes');  
for (ApexClass cls : classes) {  
    List<SetupEntityAccess> existing = [SELECT Id FROM SetupEntityAccess WHERE SetupEntityId = :cls.Id AND ParentId IN (SELECT Id FROM PermissionSet WHERE ProfileId = :profileId)];  
    if (existing.isEmpty()) {  
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
System.debug('DONE'); 
