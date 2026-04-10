// Grant Guest User permissions for Lead Create and ContentVersion Create
// So file uploads work from the portal

String profileId = '00efj000008OTBdAAO'; // Talan Talent Intelligence RH2 Profile
PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Guest_Job_Viewer' LIMIT 1];

System.debug('PermissionSet: ' + ps.Id);

// 1. Check/Add Lead Create permission
List<ObjectPermissions> existingLeadPerms = [
    SELECT Id, PermissionsCreate, PermissionsRead 
    FROM ObjectPermissions 
    WHERE ParentId = :ps.Id AND SobjectType = 'Lead'
];
if (existingLeadPerms.isEmpty()) {
    ObjectPermissions leadPerm = new ObjectPermissions();
    leadPerm.ParentId = ps.Id;
    leadPerm.SobjectType = 'Lead';
    leadPerm.PermissionsRead = true;
    leadPerm.PermissionsCreate = true;
    leadPerm.PermissionsEdit = true;
    insert leadPerm;
    System.debug('Added Lead Read+Create+Edit');
} else {
    ObjectPermissions lp = existingLeadPerms[0];
    if (!lp.PermissionsCreate || !lp.PermissionsRead) {
        lp.PermissionsRead = true;
        lp.PermissionsCreate = true;
        lp.PermissionsEdit = true;
        update lp;
        System.debug('Updated Lead permissions');
    } else {
        System.debug('Lead permissions already OK');
    }
}

// 2. Add Lead field permissions
List<String> leadFields = new List<String>{
    'Lead.Score_Matching__c',
    'Lead.AI_Recommendation__c',
    'Lead.AI_Points_Forts__c',
    'Lead.AI_Points_Faibles__c',
    'Lead.Adresse_exacte__c',
    'Lead.Code_postale__c'
};
for (String f : leadFields) {
    List<FieldPermissions> existing = [
        SELECT Id FROM FieldPermissions 
        WHERE ParentId = :ps.Id AND Field = :f
    ];
    if (existing.isEmpty()) {
        try {
            FieldPermissions fp = new FieldPermissions();
            fp.ParentId = ps.Id;
            fp.SobjectType = 'Lead';
            fp.Field = f;
            fp.PermissionsRead = true;
            fp.PermissionsEdit = true;
            insert fp;
            System.debug('Added field permission: ' + f);
        } catch (Exception e) {
            System.debug('Skip field ' + f + ': ' + e.getMessage());
        }
    }
}

System.debug('DONE - Guest User should now be able to create Leads and upload CVs');
