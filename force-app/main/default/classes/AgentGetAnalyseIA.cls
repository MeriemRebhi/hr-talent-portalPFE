public without sharing class AgentGetAnalyseIA {

    public class Input {
        @InvocableVariable(label='Email candidat' required=true)
        public String email;
    }

    public class Output {
        @InvocableVariable(label='Points forts')
        public String pointsForts;
        @InvocableVariable(label='Points à améliorer')
        public String pointsFaibles;
        @InvocableVariable(label='Recommandation')
        public String recommendation;
        @InvocableVariable(label='Score IA')
        public Decimal score;
    }

    @InvocableMethod(
        label='Obtenir analyse IA du CV'
        description='Retourne les points forts, points faibles et recommandation IA du meilleur CV du candidat.'
        category='Candidat RH'
    )
    public static List<Output> execute(List<Input> inputs) {
        List<Output> results = new List<Output>();
        for (Input inp : inputs) {
            Output out = new Output();
            List<Lead> leads = [
                SELECT Score_Matching__c, AI_Recommendation__c,
                       AI_Points_Forts__c, AI_Points_Faibles__c
                FROM Lead
                WHERE Email = :inp.email AND LeadSource = 'Talent Portal'
                  AND Score_Matching__c != null
                ORDER BY Score_Matching__c DESC LIMIT 1
            ];
            if (leads.isEmpty()) {
                out.score = 0;
                out.pointsForts = 'Non disponible';
                out.pointsFaibles = 'Non disponible';
                out.recommendation = 'CV pas encore analysé.';
            } else {
                Lead l = leads[0];
                out.score = l.Score_Matching__c;
                out.pointsForts     = l.AI_Points_Forts__c   != null ? l.AI_Points_Forts__c   : 'Non disponible';
                out.pointsFaibles   = l.AI_Points_Faibles__c != null ? l.AI_Points_Faibles__c : 'Non disponible';
                out.recommendation  = l.AI_Recommendation__c != null ? l.AI_Recommendation__c : 'Non disponible';
            }
            results.add(out);
        }
        return results;
    }
}
