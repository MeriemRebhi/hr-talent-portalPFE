// Supprimer toutes les Opportunities "Candidature" qui ont le mauvais RecordType Job_Posting
List<Opportunity> parasites = [SELECT Id, Name FROM Opportunity WHERE RecordType.DeveloperName = 'Job_Posting' AND Name LIKE '%Candidature%'];
System.debug('🗑️ Parasites trouvés: ' + parasites.size());
for (Opportunity o : parasites) {
    System.debug('   → ' + o.Name + ' (' + o.Id + ')');
}
if (!parasites.isEmpty()) {
    delete parasites;
    System.debug('✅ Supprimés');
}
