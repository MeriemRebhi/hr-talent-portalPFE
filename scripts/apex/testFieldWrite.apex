// Test direct insert with all fields to verify they work
Technical_Question__c tq = new Technical_Question__c();
tq.Problem_Text__c = 'Test problem text - this is a sample problem';
tq.Problem_Type__c = 'code';
tq.Difficulty__c = 'easy';
tq.Expected_Solution__c = 'def solution(): return 42';
tq.Evaluation_Criteria__c = 'Logic|Performance|Readability|Edge cases';
tq.Time_Limit__c = 300;

insert tq;
System.debug('Inserted test question: ' + tq.Id);

// Read back
Technical_Question__c loaded = [SELECT Id, Problem_Text__c, Problem_Type__c, Difficulty__c, 
    Expected_Solution__c, Evaluation_Criteria__c, Time_Limit__c
    FROM Technical_Question__c WHERE Id = :tq.Id];

System.debug('Problem_Text__c: ' + (loaded.Problem_Text__c != null ? 'HAS VALUE (' + loaded.Problem_Text__c.length() + ' chars)' : 'NULL'));
System.debug('Problem_Type__c: ' + loaded.Problem_Type__c);
System.debug('Difficulty__c: ' + loaded.Difficulty__c);
System.debug('Expected_Solution__c: ' + (loaded.Expected_Solution__c != null ? 'HAS VALUE' : 'NULL'));
System.debug('Evaluation_Criteria__c: ' + (loaded.Evaluation_Criteria__c != null ? 'HAS VALUE' : 'NULL'));
System.debug('Time_Limit__c: ' + loaded.Time_Limit__c);

// Also check existing Groq-generated records
List<Technical_Question__c> existing = [SELECT Id, Problem_Text__c, Problem_Type__c, Difficulty__c, 
    Expected_Solution__c, Evaluation_Criteria__c, Time_Limit__c, CreatedDate
    FROM Technical_Question__c WHERE Id != :tq.Id ORDER BY CreatedDate DESC LIMIT 5];
System.debug('=== Existing Groq records ===');
for (Technical_Question__c eq : existing) {
    System.debug('Record ' + eq.Id + ': text=' + (eq.Problem_Text__c != null ? eq.Problem_Text__c.left(50) : 'NULL') 
        + ' | type=' + eq.Problem_Type__c + ' | diff=' + eq.Difficulty__c);
}

// Clean up test record
delete tq;
System.debug('Cleaned up test record');
