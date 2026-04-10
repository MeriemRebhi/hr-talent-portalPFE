// Fix: changer le RecordType de l'Opportunity bouhajja de Job_Posting vers Application
List<RecordType> rt = [SELECT Id FROM RecordType WHERE SObjectType='Opportunity' AND DeveloperName='Application' LIMIT 1];
if (!rt.isEmpty()) {
    Opportunity opp = new Opportunity(Id = '006fj00000BBFJxAAP');
    opp.RecordTypeId = rt[0].Id;
    opp.StageName = 'Gaming';
    update opp;
    System.debug('✅ Opportunity corrigée → RecordType Application');
} else {
    System.debug('❌ RecordType Application non trouvé');
}
