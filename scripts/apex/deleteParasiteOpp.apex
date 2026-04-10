// Supprimer l'Opportunity parasite "bouhajja - Candidature (20%)" qui a le mauvais RecordType
Opportunity opp = [SELECT Id, Name, RecordType.DeveloperName FROM Opportunity WHERE Id = '006fj00000BBFJxAAP' LIMIT 1];
System.debug('🗑️ Suppression de: ' + opp.Name + ' (RT=' + opp.RecordType.DeveloperName + ')');
delete opp;
System.debug('✅ Opportunity supprimée');
