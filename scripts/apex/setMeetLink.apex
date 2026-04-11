// Set a Meet link on the test opportunity
Opportunity opp = [SELECT Id, Name, Technical_Meet_Link__c FROM Opportunity WHERE Id = '006fj00000BF3X7AAL'];
opp.Technical_Meet_Link__c = 'https://meet.google.com/test-demo-link';
update opp;
System.debug('Meet link set for: ' + opp.Name);
