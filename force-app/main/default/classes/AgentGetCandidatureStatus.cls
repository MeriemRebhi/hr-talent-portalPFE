public without sharing class AgentGetCandidatureStatus {

    public class Input {
        @InvocableVariable(label='Email candidat' required=true)
        public String email;
    }

    public class Output {
        @InvocableVariable(label='Résumé des candidatures')
        public String resume;
        @InvocableVariable(label='Nombre de candidatures')
        public Integer nombre;
        @InvocableVariable(label='Meilleur score')
        public Decimal meilleurScore;
        @InvocableVariable(label='Statut le plus récent')
        public String statut;
    }

    @InvocableMethod(
        label='Obtenir statut candidature'
        description='Retourne le statut, score IA et recommandation des candidatures du candidat.'
        category='Candidat RH'
    )
    public static List<Output> execute(List<Input> inputs) {
        List<Output> results = new List<Output>();
        for (Input inp : inputs) {
            Output out = new Output();
            List<Lead> leads = [
                SELECT Id, Status, Score_Matching__c, AI_Recommendation__c, Company,
                       CreatedDate, IsConverted
                FROM Lead
                WHERE Email = :inp.email AND LeadSource = 'Talent Portal'
                ORDER BY CreatedDate DESC LIMIT 5
            ];
            if (leads.isEmpty()) {
                out.resume = 'Aucune candidature trouvée.';
                out.nombre = 0; out.statut = 'Aucune'; out.meilleurScore = 0;
            } else {
                out.nombre = leads.size();
                Decimal maxScore = 0;
                String txt = leads.size() + ' candidature(s) :\n';
                Integer idx = 1;
                for (Lead l : leads) {
                    Decimal sc = l.Score_Matching__c != null ? l.Score_Matching__c : 0;
                    if (sc > maxScore) maxScore = sc;
                    txt += idx + '. ' + (l.Company != null ? l.Company : 'Non précisé');
                    txt += ' | ' + getLabel(l.Status, l.IsConverted);
                    txt += ' | Score: ' + sc.intValue() + '%\n';
                    idx++;
                }
                out.resume = txt;
                out.meilleurScore = maxScore;
                out.statut = getLabel(leads[0].Status, leads[0].IsConverted);
            }
            results.add(out);
        }
        return results;
    }

    private static String getLabel(String s, Boolean converted) {
        if (converted == true) return 'Profil validé et converti';
        if (s == null) return 'En cours';
        if (s.contains('Validée')) return 'Validée — conversion en cours';
        if (s.contains('Réfusé'))  return 'Non retenue';
        if (s.contains('Parsing')) return 'Analyse IA en cours';
        return s;
    }
}
