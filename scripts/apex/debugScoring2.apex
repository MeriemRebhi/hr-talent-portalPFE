// Check the 3 most recent leads with no score
List<Lead> leads = [
    SELECT Id, FirstName, LastName, Email, Status, Score_Matching__c, Description, CreatedDate
    FROM Lead 
    WHERE LeadSource = 'Talent Portal' AND Score_Matching__c = null AND IsConverted = false
    ORDER BY CreatedDate DESC 
    LIMIT 3
];

System.debug('=== LEADS SANS SCORE ===');
for (Lead l : leads) {
    System.debug('Lead ' + l.Id + ' | ' + l.Email + ' | Status: ' + l.Status + ' | Created: ' + l.CreatedDate);
    System.debug('  Description: ' + (l.Description != null ? l.Description.substring(0, Math.min(200, l.Description.length())) : 'NULL'));
    
    // Check ContentDocumentLink on this lead
    List<ContentDocumentLink> cdls = [
        SELECT ContentDocumentId, ContentDocument.Title, SystemModstamp 
        FROM ContentDocumentLink 
        WHERE LinkedEntityId = :l.Id
    ];
    System.debug('  CV Attachments: ' + cdls.size());
    for (ContentDocumentLink cdl : cdls) {
        System.debug('    - ' + cdl.ContentDocument.Title + ' (linked: ' + cdl.SystemModstamp + ')');
    }
}

// Check recent ContentVersion to see if CVs were uploaded
List<ContentVersion> recentCVs = [
    SELECT Id, Title, FileExtension, ContentDocumentId, CreatedDate, ContentSize
    FROM ContentVersion 
    WHERE IsLatest = true 
    ORDER BY CreatedDate DESC 
    LIMIT 5
];
System.debug('=== 5 DERNIERS FICHIERS UPLOADÉS ===');
for (ContentVersion cv : recentCVs) {
    System.debug('File: ' + cv.Title + '.' + cv.FileExtension + ' | Size: ' + cv.ContentSize + ' | Created: ' + cv.CreatedDate);
    
    // Check where this file is linked
    List<ContentDocumentLink> links = [
        SELECT LinkedEntityId, LinkedEntity.Type 
        FROM ContentDocumentLink 
        WHERE ContentDocumentId = :cv.ContentDocumentId
    ];
    for (ContentDocumentLink lnk : links) {
        System.debug('    Linked to: ' + lnk.LinkedEntityId + ' (Type: ' + lnk.LinkedEntity.Type + ')');
    }
}

// Check if trigger fired recently by looking at Lead status changes
List<Lead> iaParsing = [
    SELECT Id, Email, Status, Score_Matching__c 
    FROM Lead 
    WHERE Status = 'Condidature - IA Parsing' 
    LIMIT 5
];
System.debug('=== LEADS EN "IA Parsing" (trigger fired but scoring failed) ===');
System.debug('Count: ' + iaParsing.size());
for (Lead l : iaParsing) {
    System.debug('  ' + l.Email + ' | Score: ' + l.Score_Matching__c);
}
