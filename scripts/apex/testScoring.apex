Lead lead = [
    SELECT Id, FirstName, LastName, Email, Description, Score_Matching__c
    FROM Lead
    WHERE IsConverted = false
    ORDER BY CreatedDate DESC
    LIMIT 1
];
System.debug('=== Description brute: ' + lead.Description + ' ===');

// Vérifier CV
List<ContentDocumentLink> links = [
    SELECT ContentDocumentId FROM ContentDocumentLink
    WHERE LinkedEntityId = :lead.Id
];
System.debug('=== CV count: ' + links.size() + ' ===');

if (!links.isEmpty()) {
    ContentVersion cv = [
        SELECT Id, Title, FileExtension, TextPreview, VersionData
        FROM ContentVersion
        WHERE ContentDocumentId = :links[0].ContentDocumentId
        AND IsLatest = true LIMIT 1
    ];
    System.debug('=== CV Title: ' + cv.Title + ' ===');
    System.debug('=== CV Ext: ' + cv.FileExtension + ' ===');
    System.debug('=== TextPreview: ' + cv.TextPreview + ' ===');
    System.debug('=== VersionData size: ' + cv.VersionData.size() + ' bytes ===');
}