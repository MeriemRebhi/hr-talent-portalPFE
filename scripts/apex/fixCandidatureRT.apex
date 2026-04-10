// Corriger les Opportunités "candidature" qui ont le mauvais RecordType Job_Posting → Application
// Application RT Id: 012fj000004TGblAAG (active mais pas available pour ce profil, on utilise l'Id directement)
Id appRtId = '012fj000004TGblAAG';

List<Opportunity> toFix = [
    SELECT Id, Name, RecordTypeId, RecordType.DeveloperName
    FROM Opportunity
    WHERE RecordType.DeveloperName = 'Job_Posting'
    AND Name LIKE '%Candidature%'
];

System.debug('=== OPPORTUNITÉS À CORRIGER ===');
for (Opportunity o : toFix) {
    System.debug('Fixing: ' + o.Name + ' (RT: ' + o.RecordType.DeveloperName + ' → Application)');
    o.RecordTypeId = appRtId;
}

if (!toFix.isEmpty()) {
    update toFix;
    System.debug('✅ ' + toFix.size() + ' opportunités corrigées vers RecordType Application');
} else {
    System.debug('Aucune opportunité à corriger');
}
