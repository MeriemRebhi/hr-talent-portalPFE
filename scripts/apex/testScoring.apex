// Vérifier le dernier Lead scoré
Lead lead = [
    SELECT Id, FirstName, Email, Score_Matching__c, 
           Status, IsConverted, AI_Recommendation__c
    FROM Lead
    WHERE IsConverted = false
    ORDER BY LastModifiedDate DESC
    LIMIT 1
];
System.debug('=== Score: ' + lead.Score_Matching__c + ' ===');
System.debug('=== Status: ' + lead.Status + ' ===');
System.debug('=== IsConverted: ' + lead.IsConverted + ' ===');

// Vérifier si le trigger Platform Event existe
List<ApexTrigger> triggers = [
    SELECT Name, Status FROM ApexTrigger 
    WHERE Name LIKE '%Convert%' OR Name LIKE '%Lead%'
];
System.debug('=== Triggers: ' + triggers + ' ===');