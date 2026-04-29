public with sharing class RHFitPromptFlowAction {

    public class Input {
        @InvocableVariable(label='Job Offer Context' required=true)
        public String jobOfferContext;

        @InvocableVariable(label='Candidate Context' required=true)
        public String candidateContext;

        @InvocableVariable(label='Previous Interview Context')
        public String previousInterviewContext;

        @InvocableVariable(label='Recruiter Guidance')
        public String recruiterGuidance;
    }

    public class Output {
        @InvocableVariable(label='Prompt Response')
        public String promptResponse;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Generate RH Fit Questions (Einstein Prompt)'
        description='Calls RH_Fit_Interview_Question_Generator and returns promptResponse JSON.'
        category='Candidat RH'
    )
    public static List<Output> generate(List<Input> inputs) {
        List<Output> results = new List<Output>();
        if (inputs == null) {
            return results;
        }

        for (Input req : inputs) {
            Output out = new Output();
            try {
                Invocable.Action action = Invocable.Action.createCustomAction(
                    'generatePromptResponse',
                    null,
                    'RH_Fit_Interview_Question_Generator'
                );

                action.setInvocationParameter('Input:JobOfferContext', req.jobOfferContext);
                action.setInvocationParameter('Input:CandidateContext', req.candidateContext);
                action.setInvocationParameter('Input:PreviousInterviewContext', req.previousInterviewContext);
                action.setInvocationParameter('Input:RecruiterGuidance', req.recruiterGuidance);

                List<Invocable.Action.Result> actionResults = action.invoke();
                if (actionResults == null || actionResults.isEmpty()) {
                    out.errorMessage = 'No result returned by Einstein prompt action.';
                } else if (!actionResults[0].isSuccess()) {
                    List<Invocable.Action.Error> errors = actionResults[0].getErrors();
                    out.errorMessage = (errors != null && !errors.isEmpty())
                        ? errors[0].getMessage()
                        : 'Prompt action failed.';
                } else {
                    Map<String, Object> outputParams = actionResults[0].getOutputParameters();
                    if (outputParams != null) {
                        Object responseVal = outputParams.get('promptResponse');
                        out.promptResponse = responseVal == null ? null : String.valueOf(responseVal);
                    }
                }
            } catch (Exception e) {
                out.errorMessage = e.getMessage();
            }
            results.add(out);
        }
        return results;
    }
}
