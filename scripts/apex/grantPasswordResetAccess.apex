String profileId = '00efj000008OTBdAAO';
ApexClass cls = [SELECT Id FROM ApexClass WHERE Name = 'PasswordResetController' LIMIT 1];
PermissionSet profPS = [SELECT Id FROM PermissionSet WHERE ProfileId = :profileId AND IsOwnedByProfile = true LIMIT 1];
List<SetupEntityAccess> existing = [SELECT Id FROM SetupEntityAccess WHERE SetupEntityId = :cls.Id AND ParentId = :profPS.Id];
if (existing.isEmpty()) {
    SetupEntityAccess sea = new SetupEntityAccess();
    sea.ParentId = profPS.Id;
    sea.SetupEntityId = cls.Id;
    insert sea;
    System.debug('GRANTED access to PasswordResetController');
} else {
    System.debug('Already has access to PasswordResetController');
}
