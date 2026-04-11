// Grant Guest User CRUD on Technical_Question__c
String profileId = '00efj000008OTBdAAO';
PermissionSet profPS = [SELECT Id FROM PermissionSet WHERE ProfileId = :profileId AND IsOwnedByProfile = true LIMIT 1];

List<ObjectPermissions> existing = [
    SELECT Id FROM ObjectPermissions
    WHERE ParentId = :profPS.Id AND SobjectType = 'Technical_Question__c'
];

if (existing.isEmpty()) {
    ObjectPermissions op = new ObjectPermissions();
    op.ParentId = profPS.Id;
    op.SobjectType = 'Technical_Question__c';
    op.PermissionsCreate = true;
    op.PermissionsRead = true;
    op.PermissionsEdit = false;
    op.PermissionsDelete = false;
    insert op;
    System.debug('Created object permissions for Technical_Question__c');
} else {
    System.debug('Object permissions already exist');
}
System.debug('DONE');
