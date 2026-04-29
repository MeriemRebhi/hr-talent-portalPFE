import { LightningElement, track, wire } from 'lwc';
import getRecruteurData   from '@salesforce/apex/InternalDashboardController.getRecruteurData';
import updateOpportunityStage from '@salesforce/apex/InternalDashboardController.updateOpportunityStage';
import scheduleGamingTest from '@salesforce/apex/InternalDashboardController.scheduleGamingTest';
import scheduleBatchGamingTests from '@salesforce/apex/InternalDashboardController.scheduleBatchGamingTests';
import cancelGamingTest from '@salesforce/apex/InternalDashboardController.cancelGamingTest';
import scheduleTechnicalInterview from '@salesforce/apex/InternalDashboardController.scheduleTechnicalInterview';
import scheduleArchitectureInterview from '@salesforce/apex/InternalDashboardController.scheduleArchitectureInterview';
import validateArchitectureInterview from '@salesforce/apex/InternalDashboardController.validateArchitectureInterview';
import scheduleRHFitInterview from '@salesforce/apex/InternalDashboardController.scheduleRHFitInterview';
import validateRHFitInterview from '@salesforce/apex/InternalDashboardController.validateRHFitInterview';
import getJobPostings from '@salesforce/apex/InternalDashboardController.getJobPostings';
import createJobPosting from '@salesforce/apex/InternalDashboardController.createJobPosting';
import toggleJobPosting from '@salesforce/apex/InternalDashboardController.toggleJobPosting';
import rescoreCandidat from '@salesforce/apex/InternalDashboardController.rescoreCandidat';
import generateJobDescription from '@salesforce/apex/InternalDashboardController.generateJobDescription';
import generateGamingQuestionsApex from '@salesforce/apex/GamingQuestionService.generateQuestions';
import getGenerationStatus from '@salesforce/apex/GamingQuestionService.getGenerationStatus';
import generateTechQuestionsApex from '@salesforce/apex/TechnicalQuestionService.generateQuestions';
import getTechGenerationStatus from '@salesforce/apex/TechnicalQuestionService.getGenerationStatus';
import validateScore from '@salesforce/apex/TechnicalInterviewController.validateScore';
import getInterviewDetails from '@salesforce/apex/TechnicalInterviewController.getInterviewDetails';
import generateRHFitQuestionsApex from '@salesforce/apex/RHFitInterviewController.generateQuestions';
import uploadRHFitAudioApex from '@salesforce/apex/RHFitInterviewController.uploadAudio';
import processRHFitAudioApex from '@salesforce/apex/RHFitInterviewController.processAudio';
import getRHFitProcessingStatusApex from '@salesforce/apex/RHFitInterviewController.getProcessingStatus';

const STAGE_ORDER = ['Gaming', 'Technique', 'Architecture', 'RH Fit', 'Closed Won'];

const STAGE_BADGE = {
    'Gaming':       'badge s-gaming',
    'Technique':    'badge s-technique',
    'Architecture': 'badge s-architecture',
    'RH Fit':       'badge s-rhfit',
    'Closed Won':   'badge s-won',
    'Closed Lost':  'badge s-lost'
};

const RECO_BADGE = {
    'high':   'reco-pill reco-high',
    'mid':    'reco-pill reco-mid',
    'low':    'reco-pill reco-low',
    'reject': 'reco-pill reco-reject',
    'none':   'reco-pill reco-none'
};

const SCORE_BAR = {
    'high':   'score-bar bar-high',
    'mid':    'score-bar bar-mid',
    'low':    'score-bar bar-low',
    'reject': 'score-bar bar-reject',
    'none':   'score-bar bar-none'
};

export default class RecruteurDashboard extends LightningElement {

    @track isLoaded = false;
    @track allOpps = [];
    @track filteredOpps = [];
    @track activeStage = '';
    @track toastMessage = '';
    @track toastClass = 'rdb-toast toast-success';

    // Advanced filters
    @track searchTerm = '';
    @track jobFilterVal = '';
    @track scoreFilterVal = '';
    @track sortFilterVal = '';

    // KPIs
    @track totalCandidats = 0;
    @track enGaming = 0;
    @track enTechnique = 0;
    @track enArchitecture = 0;
    @track enRHFit = 0;
    @track closedCount = 0;

    // Planning modal
    @track showPlanModal = false;
    @track planOppId = '';
    @track planCandidatName = '';
    @track planDateTime = '';
    @track planDuration = '60';
    @track isSending = false;

    // Technical interview planning modal
    @track showTechPlanModal = false;
    @track techPlanOppId = '';
    @track techPlanCandidatName = '';
    @track techPlanDateTime = '';
    @track techPlanDuration = '60';
    @track techPlanMeetUrl = '';
    @track isTechSending = false;

    // Architecture interview planning modal
    @track showArchPlanModal = false;
    @track archPlanOppId = '';
    @track archPlanCandidatName = '';
    @track archPlanDateTime = '';
    @track archPlanDuration = '45';
    @track isArchSending = false;

    // RH Fit interview planning modal
    @track showRHFitPlanModal = false;
    @track rhfitPlanOppId = '';
    @track rhfitPlanCandidatName = '';
    @track rhfitPlanDateTime = '';
    @track rhfitPlanDuration = '45';
    @track isRHFitSending = false;

    // Batch planning
    @track selectedMap = {};
    @track showBatchModal = false;
    @track batchDateTime = '';
    @track batchDuration = '60';
    @track batchGap = '30';
    @track batchPreview = [];
    @track isBatchSending = false;

    // Tab system
    @track activeTab = 'candidatures';

    // Job postings
    @track jobPostings = [];
    @track totalOffres = 0;
    @track showCreateOfferModal = false;
    @track isCreatingOffer = false;
    @track offerTitle = '';
    @track offerDepartment = '';
    @track offerLocation = '';
    @track offerContract = '';
    @track offerSalary = '';
    @track offerDescription = '';
    @track offerCloseDate = '';
    @track isGeneratingDesc = false;

    // Detail modal
    @track showDetailModal = false;
    @track detailOpp = {};

    // Validation modal
    @track showValidationModal = false;
    @track validationOppId = '';
    @track validationScore = 0;
    @track validationOriginalScore = 0;
    @track validationDecision = '';
    @track isValidating = false;
    @track validationDetails = null;
    @track loadingDetails = false;

    // Architecture validation modal
    @track showArchValidationModal = false;
    @track archValidationOppId = '';
    @track archValidationCandidateName = '';
    @track archDesignScore = 0;
    @track archTradeoffScore = 0;
    @track archScalabilityScore = 0;
    @track archCommunicationScore = 0;
    @track archCollaborationScore = 0;
    @track archValidationDecision = '';
    @track archValidationNotes = '';
    @track isArchValidating = false;

    // RH Fit question modal
    @track showRHFitQuestionModal = false;
    @track rhfitQuestionOppId = '';
    @track rhfitQuestionCandidateName = '';
    @track rhfitQuestionsText = '';
    @track isGeneratingRHFitQuestions = false;

    // RH Fit validation modal
    @track showRHFitValidationModal = false;
    @track rhfitValidationOppId = '';
    @track rhfitValidationCandidateName = '';
    @track rhfitValidationAIScore = 0;
    @track rhfitValidationSentiment = '';
    @track rhfitValidationScore = 0;
    @track rhfitValidationDecision = '';
    @track rhfitValidationNotes = '';
    @track isRHFitValidating = false;

    // RH Fit processing modal (recruiter-only)
    @track showRHFitProcessModal = false;
    @track rhfitProcessOppId = '';
    @track rhfitProcessCandidateName = '';
    @track rhfitProcessStatus = '';
    @track rhfitProcessHasAudio = false;
    @track rhfitProcessFileName = '';
    @track isRHFitUploadingAudio = false;
    @track isRHFitProcessingAudio = false;
    @track rhfitProcessAIScore = null;
    @track rhfitProcessSentimentScore = null;
    @track rhfitProcessSentimentLabel = '';
    @track rhfitProcessTranscription = '';
    @track rhfitProcessAIFeedback = '';
    rhfitSelectedAudioFile = null;
    rhfitProcessPollingTimer = null;
    rhfitProcessPollingAttempts = 0;

    // Observation criteria (stars 0-5)
    @track obsCommunication = 0;
    @track obsApproach = 0;
    @track obsAutonomy = 0;
    @track observationNotes = '';
    @track existingManagerNotes = '';

    get isCandidaturesTab() { return this.activeTab === 'candidatures'; }
    get isOffresTab() { return this.activeTab === 'offres'; }
    get tabCandClass() { return 'rdb-tab' + (this.activeTab === 'candidatures' ? ' tab-active' : ''); }
    get tabOffresClass() { return 'rdb-tab' + (this.activeTab === 'offres' ? ' tab-active' : ''); }

    // Detail getters
    get detailName() { return this.detailOpp.Name || ''; }
    get detailInitials() { return this.detailOpp.initials || ''; }
    get detailJob() { return this.detailOpp.jobTitle || '—'; }
    get detailStage() { return this.detailOpp.StageName || ''; }
    get detailScore() { return this.detailOpp.score != null ? this.detailOpp.score : '—'; }
    get detailReco() { return this.detailOpp.reco || ''; }
    get detailRecoBadge() { return this.detailOpp.recoBadge || 'reco-pill reco-none'; }
    get detailEmail() { return this.detailOpp.leadEmail || ''; }
    get detailPhone() { return this.detailOpp.leadPhone || ''; }
    get detailAiReco() { return this.detailOpp.aiReco || ''; }
    get detailForts() { return this.detailOpp.aiForts || ''; }
    get detailHasGaming() { return this.detailOpp.hasGamingScore; }
    get detailGamingScore() { return this.detailOpp.gamingScore != null ? this.detailOpp.gamingScore : ''; }
    get detailGamingLabel() { return this.detailOpp.gamingResultLabel || ''; }
    get detailGamingBadge() { return this.detailOpp.gamingScoreBadge || ''; }

    // Technical interview detail getters
    get detailHasTech() { return this.detailOpp.hasTechScore; }
    get detailTechScore() { return this.detailOpp.techScore != null ? this.detailOpp.techScore : ''; }
    get detailTechLabel() { return this.detailOpp.techResultLabel || ''; }
    get detailTechBadge() { return this.detailOpp.techScoreBadge || ''; }
    get detailTechComposite() { return this.detailOpp.techComposite; }
    get detailHasManagerScore() { return this.detailOpp.hasManagerScore; }
    get detailManagerScore() { return this.detailOpp.managerValidatedScore; }
    get detailHasArch() { return this.detailOpp.hasArchScore; }
    get detailArchScore() { return this.detailOpp.archScore != null ? this.detailOpp.archScore : ''; }
    get detailArchStatus() { return this.detailOpp.archStatus || 'Non passe'; }
    get detailHasRHFitPlan() { return !!this.detailOpp.rhfitScheduled; }
    get detailRHFitDateFmt() { return this.detailOpp.rhfitDateFmt || ''; }
    get detailRHFitStatus() { return this.detailOpp.rhfitStatus || 'Non planifie'; }
    get detailHasRHFitAIScore() { return !!this.detailOpp.hasRHFitAIScore; }
    get detailRHFitAIScore() { return this.detailOpp.rhfitAIScore != null ? this.detailOpp.rhfitAIScore : ''; }
    get detailRHFitSentimentLabel() { return this.detailOpp.rhfitSentimentLabel || 'N/A'; }
    get detailRHFitSentimentClass() {
        const s = (this.detailOpp.rhfitSentimentLabel || '').toLowerCase();
        if (s.includes('posit')) return 'rhfit-sentiment-pill rhfit-sentiment-positive';
        if (s.includes('negat')) return 'rhfit-sentiment-pill rhfit-sentiment-negative';
        if (s.includes('mitig')) return 'rhfit-sentiment-pill rhfit-sentiment-mixed';
        return 'rhfit-sentiment-pill rhfit-sentiment-neutral';
    }
    get detailHasRHFitValidatedScore() { return !!this.detailOpp.hasRHFitValidatedScore; }
    get detailRHFitValidatedScore() { return this.detailOpp.rhfitValidatedScore != null ? this.detailOpp.rhfitValidatedScore : ''; }
    get detailRHFitQuestionsReady() { return !!this.detailOpp.rhfitQuestionsReady; }
    get detailCanValidateArch() {
        return this.detailOpp && this.detailOpp.StageName === 'Architecture' && this.detailOpp.archScheduled;
    }
    get detailCanManageRHFit() {
        return this.detailOpp && this.detailOpp.StageName === 'RH Fit';
    }
    get detailCanValidateRHFit() {
        return this.detailCanManageRHFit && this.detailOpp.rhfitScheduled;
    }
    get detailCanProcessRHFit() {
        return this.detailCanManageRHFit && this.detailOpp.rhfitScheduled;
    }

    get planOppShortId() {
        return this.planOppId ? this.planOppId.substring(0, 15) : '';
    }

    @wire(getRecruteurData)
    wiredData({ data, error }) {
        if (data) {
            this.applyDashboardData(data);
        } else if (error) {
            this.isLoaded = true;
        }
    }

    applyDashboardData(data) {
        this.totalCandidats = data.totalCandidats || 0;
        this.enGaming = data.enGaming || 0;
        this.enTechnique = data.enTechnique || 0;
        this.enArchitecture = data.enArchitecture || 0;
        this.enRHFit = data.enRHFit || 0;
        this.closedCount = data.closed || 0;
        this.allOpps = (data.rows || []).map(o => this.mapOpp(o));
        this.applyFilter();
        this.isLoaded = true;
    }

    refreshDashboardData() {
        return getRecruteurData()
            .then(data => {
                this.applyDashboardData(data);
            })
            .catch(() => {
                this.isLoaded = true;
            });
    }

    mapOpp(o) {
        const stage    = o.StageName || '';
        const idx      = STAGE_ORDER.indexOf(stage);
        const nextStage = idx >= 0 && idx < STAGE_ORDER.length - 1 ? STAGE_ORDER[idx + 1] : '';
        const isClosed  = stage.startsWith('Closed');
        const score     = o.score != null ? Math.round(o.score) : null;
        const recoType  = o.recoType || 'none';
        const name      = o.Name || '';
        const parts     = name.trim().split(' ');
        const initials  = parts.length >= 2
            ? (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
            : name.substring(0, 2).toUpperCase();

        // Gaming test
        const gamingScheduled = !!o.gamingDateTime;
        let gamingDateFmt = '';
        if (gamingScheduled) {
            const dt = new Date(o.gamingDateTime);
            gamingDateFmt = dt.toLocaleDateString('fr-FR') + ' à ' + dt.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
        }

        // RH Fit UI state
        const rhfitScheduled = !!o.rhfitDateTime;
        const rhfitStatus = (o.rhfitStatus || '').trim();
        const rhfitStatusLower = rhfitStatus.toLowerCase();
        const rhfitHasAIScore = o.rhfitAIScore != null;
        const rhfitHasValidatedScore = o.rhfitValidatedScore != null;
        const rhfitIsValidated = rhfitHasValidatedScore || rhfitStatusLower.includes('valid');
        const rhfitAnalysisReady = rhfitHasAIScore || rhfitStatusLower.includes('completed');
        const rhfitInProgress = rhfitStatusLower.includes('processing');

        let rhfitState = 'to_plan';
        if (!rhfitScheduled) {
            rhfitState = 'to_plan';
        } else if (rhfitIsValidated) {
            rhfitState = 'validated';
        } else if (rhfitAnalysisReady) {
            rhfitState = 'analysis_ready';
        } else if (rhfitInProgress) {
            rhfitState = 'in_progress';
        } else {
            rhfitState = 'planned';
        }

        const rhfitStateLabel = (() => {
            switch (rhfitState) {
                case 'validated': return 'Validé';
                case 'analysis_ready': return 'Analyse prête';
                case 'in_progress': return 'En cours';
                case 'planned': return 'Planifié';
                default: return 'À planifier';
            }
        })();

        const rhfitStateClass = (() => {
            switch (rhfitState) {
                case 'validated': return 'rhfit-state-pill rhfit-state-validated';
                case 'analysis_ready': return 'rhfit-state-pill rhfit-state-analysis';
                case 'in_progress': return 'rhfit-state-pill rhfit-state-progress';
                case 'planned': return 'rhfit-state-pill rhfit-state-planned';
                default: return 'rhfit-state-pill rhfit-state-toplan';
            }
        })();

        const rhfitPrimaryAction = (() => {
            switch (rhfitState) {
                case 'validated': return 'report';
                case 'analysis_ready': return 'validate';
                case 'in_progress': return 'process';
                case 'planned': return 'process';
                default: return 'plan';
            }
        })();

        const rhfitPrimaryLabel = (() => {
            switch (rhfitPrimaryAction) {
                case 'report': return 'Voir rapport';
                case 'validate': return 'Valider RH Fit';
                case 'process': return 'Traiter entretien';
                default: return 'Planifier RH Fit';
            }
        })();

        const rhfitPrimaryClass = (() => {
            switch (rhfitPrimaryAction) {
                case 'report': return 'btn-action btn-rhfit-primary btn-rhfit-report';
                case 'validate': return 'btn-action btn-rhfit-primary btn-rhfit-validate';
                case 'process': return 'btn-action btn-rhfit-primary btn-rhfit-process';
                default: return 'btn-action btn-rhfit-primary btn-rhfit-plan';
            }
        })();

        return {
            ...o,
            initials,
            jobTitle:       o.jobTitle || '',
            stageBadge:     STAGE_BADGE[stage] || 'badge s-default',
            nextStage,
            isClosed,
            isNextDisabled: !nextStage || isClosed,
            isGaming:       stage === 'Gaming',
            selected:       !!this.selectedMap[o.Id],
            score,
            hasScore:       score != null,
            scoreBarStyle:  `width:${score || 0}%`,
            scoreBarClass:  SCORE_BAR[recoType] || 'score-bar bar-none',
            recoBadge:      RECO_BADGE[recoType] || 'reco-pill reco-none',
            gamingScheduled,
            gamingDateFmt,
            gamingMeetLink: o.gamingMeetLink || '',
            // Gaming test results
            gamingScore:       o.gamingScore != null ? Math.round(o.gamingScore) : null,
            hasGamingScore:    o.gamingScore != null && o.gamingStatus === 'Completed',
            gamingScoreLabel:  o.gamingScore != null ? Math.round(o.gamingScore) + '%' : '—',
            gamingScoreBadge:  o.gamingScore >= 80 ? 'gaming-badge gaming-excellent'
                             : o.gamingScore >= 60 ? 'gaming-badge gaming-good'
                             : o.gamingScore >= 40 ? 'gaming-badge gaming-mid'
                             : o.gamingScore != null ? 'gaming-badge gaming-fail'
                             : 'gaming-badge gaming-na',
            gamingResultLabel: o.gamingScore >= 80 ? 'Excellent'
                             : o.gamingScore >= 60 ? 'Bon'
                             : o.gamingScore >= 40 ? 'Moyen'
                             : o.gamingScore != null ? 'Insuffisant'
                             : '',
            gamingPending:     o.gamingStatus !== 'Completed' && gamingScheduled,
            // Technical interview
            isTechnique:       stage === 'Technique',
            techScheduled:     !!o.techDateTime,
            techDateFmt:       (() => {
                if (!o.techDateTime) return '';
                const dt2 = new Date(o.techDateTime);
                return dt2.toLocaleDateString('fr-FR') + ' à ' + dt2.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
            })(),
            techMeetLink:      o.techMeetLink || '',
            techScore:         o.techScore != null ? Math.round(o.techScore) : null,
            hasTechScore:      o.techScore != null && o.techStatus === 'Completed',
            techScoreLabel:    o.techScore != null ? Math.round(o.techScore) + '/100' : '—',
            techScoreBadge:    o.techScore >= 70 ? 'gaming-badge gaming-excellent'
                             : o.techScore >= 50 ? 'gaming-badge gaming-good'
                             : o.techScore >= 30 ? 'gaming-badge gaming-mid'
                             : o.techScore != null ? 'gaming-badge gaming-fail'
                             : 'gaming-badge gaming-na',
            techResultLabel:   o.techScore >= 70 ? 'Excellent'
                             : o.techScore >= 50 ? 'Bon'
                             : o.techScore >= 30 ? 'Moyen'
                             : o.techScore != null ? 'Insuffisant'
                             : '',
            techPending:       o.techStatus !== 'Completed' && !!o.techDateTime,
            techComposite:     o.techComposite != null ? Math.round(o.techComposite) : null,
            managerValidatedScore: o.managerValidatedScore != null ? Math.round(o.managerValidatedScore) : null,
            hasManagerScore:   o.managerValidatedScore != null,
            techRescheduleRequested: !!o.techRescheduleRequested,
            // Architecture interview
            isArchitecture:    stage === 'Architecture',
            archScheduled:     !!o.archDateTime,
            archDateFmt:       (() => {
                if (!o.archDateTime) return '';
                const dt3 = new Date(o.archDateTime);
                return dt3.toLocaleDateString('fr-FR') + ' \u00e0 ' + dt3.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
            })(),
            archMeetLink:      o.archMeetLink || '',
            archJitsiRoom:     o.archJitsiRoom || '',
            archScore:         o.archScore != null ? Math.round(o.archScore) : null,
            hasArchScore:      o.archScore != null && o.archStatus === 'Completed',
            archScoreLabel:    o.archScore != null ? Math.round(o.archScore) + '/100' : '\u2014',
            archPending:       o.archStatus !== 'Completed' && !!o.archDateTime,
            archRescheduleRequested: !!o.archRescheduleRequested,
            // RH Fit interview
            isRHFit:          stage === 'RH Fit',
            rhfitScheduled,
            rhfitDateFmt:     (() => {
                if (!o.rhfitDateTime) return '';
                const dt4 = new Date(o.rhfitDateTime);
                return dt4.toLocaleDateString('fr-FR') + ' a ' + dt4.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
            })(),
            rhfitMeetLink:    o.rhfitMeetLink || '',
            rhfitJitsiRoom:   o.rhfitJitsiRoom || '',
            rhfitStatus,
            rhfitHasAudio:    !!o.rhfitHasAudio,
            rhfitQuestions:   o.rhfitQuestions || '',
            rhfitQuestionsReady: !!o.rhfitQuestions,
            rhfitAIScore:     o.rhfitAIScore != null ? Math.round(o.rhfitAIScore) : null,
            hasRHFitAIScore:  rhfitHasAIScore,
            rhfitSentimentScore: o.rhfitSentimentScore != null ? Math.round(o.rhfitSentimentScore * 100) / 100 : null,
            rhfitSentimentLabel: o.rhfitSentimentLabel || '',
            rhfitValidatedScore: o.rhfitValidatedScore != null ? Math.round(o.rhfitValidatedScore) : null,
            hasRHFitValidatedScore: rhfitHasValidatedScore,
            rhfitRescheduleRequested: !!o.rhfitRescheduleRequested,
            rhfitState,
            rhfitStateLabel,
            rhfitStateClass,
            rhfitPrimaryAction,
            rhfitPrimaryLabel,
            rhfitPrimaryClass,
            rhfitShowReplanAction: rhfitScheduled && rhfitPrimaryAction !== 'plan',
            rhfitShowProcessAction: rhfitScheduled && !rhfitIsValidated && rhfitPrimaryAction !== 'process',
            rhfitShowValidateAction: rhfitScheduled && rhfitAnalysisReady && !rhfitIsValidated && rhfitPrimaryAction !== 'validate',
            rhfitShowReportAction: rhfitPrimaryAction !== 'report'
        };
    }

    applyFilter() {
        let result = [...this.allOpps];

        // 1 — Stage chip filter
        if (this.activeStage) {
            if (this.activeStage === 'Closed') {
                result = result.filter(o => o.StageName && o.StageName.startsWith('Closed'));
            } else {
                result = result.filter(o => o.StageName === this.activeStage);
            }
        }

        // 2 — Search by candidate name
        if (this.searchTerm) {
            const q = this.searchTerm.toLowerCase();
            result = result.filter(o => (o.Name || '').toLowerCase().includes(q));
        }

        // 3 — Job / account filter
        if (this.jobFilterVal) {
            result = result.filter(o => o.jobTitle === this.jobFilterVal);
        }

        // 4 — Score / recommendation filter
        if (this.scoreFilterVal) {
            result = result.filter(o => {
                const s = o.score;
                if (s == null) return false;
                switch (this.scoreFilterVal) {
                    case 'high':   return s >= 70;
                    case 'mid':    return s >= 50 && s < 70;
                    case 'low':    return s >= 30 && s < 50;
                    case 'reject': return s < 30;
                    default: return true;
                }
            });
        }

        // 5 — Sort
        if (this.sortFilterVal) {
            result.sort((a, b) => {
                switch (this.sortFilterVal) {
                    case 'score-desc': return (b.score || 0) - (a.score || 0);
                    case 'score-asc':  return (a.score || 0) - (b.score || 0);
                    case 'name-asc':   return (a.Name || '').localeCompare(b.Name || '');
                    case 'name-desc':  return (b.Name || '').localeCompare(a.Name || '');
                    default: return 0;
                }
            });
        }

        this.filteredOpps = result;
    }

    filterByStage(event) {
        this.activeStage = event.currentTarget.dataset.stage;
        this.applyFilter();
    }

    // ── Advanced filter handlers ──
    handleSearch(event) {
        this.searchTerm = event.target.value;
        this.applyFilter();
    }

    handleJobFilter(event) {
        this.jobFilterVal = event.target.value;
        this.applyFilter();
    }

    handleScoreFilter(event) {
        this.scoreFilterVal = event.target.value;
        this.applyFilter();
    }

    handleSortFilter(event) {
        this.sortFilterVal = event.target.value;
        this.applyFilter();
    }

    clearAdvancedFilters() {
        this.searchTerm = '';
        this.jobFilterVal = '';
        this.scoreFilterVal = '';
        this.sortFilterVal = '';
        this.applyFilter();
    }

    get hasAdvancedFilters() {
        return this.searchTerm || this.jobFilterVal || this.scoreFilterVal || this.sortFilterVal;
    }

    get jobOptions() {
        const names = this.allOpps.map(o => o.jobTitle).filter(n => n && n !== '');
        return [...new Set(names)].sort();
    }

    // ── Stage actions ──
    advanceStage(event) {
        const id = event.currentTarget.dataset.id;
        const newStage = event.currentTarget.dataset.stage;
        if (!newStage) return;
        this.doUpdateStage(id, newStage);
    }

    cancelGamingSchedule(event) {
        const id = event.currentTarget.dataset.id;
        cancelGamingTest({ oppId: id })
            .then(() => {
                this.allOpps = this.allOpps.map(o => {
                    if (o.Id === id) {
                        const copy = { ...o };
                        copy.gamingDateTime = null;
                        copy.gamingScheduled = false;
                        copy.gamingPending = false;
                        copy.gamingDateFmt = '';
                        return copy;
                    }
                    return o;
                });
                this.applyFilter();
                this.showToast('Rendez-vous annulé avec succès', 'success');
            })
            .catch(err => {
                this.showToast('Erreur : ' + (err.body ? err.body.message : err.message), 'error');
            });
    }

    doUpdateStage(id, newStage) {
        updateOpportunityStage({ oppId: id, newStage })
            .then(() => {
                this.allOpps = this.allOpps.map(o => {
                    if (o.Id === id) return this.mapOpp({ ...o, StageName: newStage });
                    return o;
                });
                this.applyFilter();
                this.showToast('✅ Stage mis à jour : ' + newStage, 'success');
            })
            .catch(err => {
                this.showToast('❌ Erreur : ' + (err.body ? err.body.message : err.message), 'error');
            });
    }

    // ── Planning modal ──
    openPlanModal(event) {
        this.planOppId        = event.currentTarget.dataset.id;
        this.planCandidatName = event.currentTarget.dataset.name;
        this.planDuration     = '60';
        // défaut = heure système actuelle
        const now = new Date();
        const pad = n => String(n).padStart(2, '0');
        this.planDateTime = `${now.getFullYear()}-${pad(now.getMonth()+1)}-${pad(now.getDate())}T${pad(now.getHours())}:${pad(now.getMinutes())}`;
        this.showPlanModal = true;
    }

    closePlanModal() {
        this.showPlanModal = false;
        this.isSending = false;
    }

    onDateTimeChange(event) { this.planDateTime = event.target.value; }
    onDurationChange(event) { this.planDuration = event.target.value; }

    confirmSchedule() {
        if (!this.planDateTime) {
            this.showToast('⚠️ Veuillez choisir une date et heure.', 'error');
            return;
        }
        this.isSending = true;
        scheduleGamingTest({
            oppId:        this.planOppId,
            testDateTime: this.planDateTime,
            duration:     this.planDuration
        })
        .then(() => {
            this.showPlanModal = false;
            this.isSending = false;
            this.showToast('✅ Invitation envoyée ! Test planifié avec succès.', 'success');
            // Mettre à jour localement
            const meetLink = 'https://meet.jit.si/HRGaming-' + this.planOppId.substring(0, 15);
            this.allOpps = this.allOpps.map(o => {
                if (o.Id === this.planOppId) {
                    return this.mapOpp({
                        ...o,
                        gamingDateTime: this.planDateTime,
                        gamingDuration: this.planDuration,
                        gamingMeetLink: meetLink
                    });
                }
                return o;
            });
            this.applyFilter();
        })
        .catch(err => {
            this.isSending = false;
            this.showToast('❌ Erreur : ' + (err.body ? err.body.message : err.message), 'error');
        });
    }

    // ── Technical Interview Planning ──
    openTechPlanModal(event) {
        this.techPlanOppId        = event.currentTarget.dataset.id;
        this.techPlanCandidatName = event.currentTarget.dataset.name;
        this.techPlanDuration     = '60';
        this.techPlanMeetUrl      = '';
        const now = new Date();
        const pad = n => String(n).padStart(2, '0');
        this.techPlanDateTime = `${now.getFullYear()}-${pad(now.getMonth()+1)}-${pad(now.getDate())}T${pad(now.getHours())}:${pad(now.getMinutes())}`;
        this.showTechPlanModal = true;
    }

    closeTechPlanModal() {
        this.showTechPlanModal = false;
        this.isTechSending = false;
    }

    onTechDateTimeChange(event) { this.techPlanDateTime = event.target.value; }
    onTechDurationChange(event) { this.techPlanDuration = event.target.value; }
    onTechMeetUrlChange(event)  { this.techPlanMeetUrl  = event.target.value; }

    get techPlanOppShortId() {
        return this.techPlanOppId ? this.techPlanOppId.substring(0, 15) : '';
    }

    confirmTechSchedule() {
        if (!this.techPlanDateTime) {
            this.showToast('⚠️ Veuillez choisir une date et heure.', 'error');
            return;
        }
        this.isTechSending = true;
        scheduleTechnicalInterview({
            oppId:            this.techPlanOppId,
            interviewDateTime: this.techPlanDateTime,
            duration:         this.techPlanDuration,
            meetUrl:          this.techPlanMeetUrl
        })
        .then(() => {
            this.showTechPlanModal = false;
            this.isTechSending = false;
            this.showToast('✅ Invitation entretien technique envoyée !', 'success');
            const meetLink = 'https://orgfarm-3ed211f8bb-dev-ed.develop.my.site.com/home2/s/entretientechnique1?id=' + this.techPlanOppId;
            this.allOpps = this.allOpps.map(o => {
                if (o.Id === this.techPlanOppId) {
                    return this.mapOpp({
                        ...o,
                        techDateTime: this.techPlanDateTime,
                        techDuration: this.techPlanDuration,
                        techMeetLink: meetLink,
                        techStatus:   'Scheduled',
                        techRescheduleRequested: false
                    });
                }
                return o;
            });
            this.applyFilter();
        })
        .catch(err => {
            this.isTechSending = false;
            this.showToast('❌ Erreur : ' + (err.body ? err.body.message : err.message), 'error');
        });
    }

    // ── Architecture Interview Planning ──
    openArchPlanModal(event) {
        this.archPlanOppId        = event.currentTarget.dataset.id;
        this.archPlanCandidatName = event.currentTarget.dataset.name;
        this.archPlanDuration     = '45';
        const now = new Date();
        const pad = n => String(n).padStart(2, '0');
        this.archPlanDateTime = `${now.getFullYear()}-${pad(now.getMonth()+1)}-${pad(now.getDate())}T${pad(now.getHours())}:${pad(now.getMinutes())}`;
        this.showArchPlanModal = true;
    }

    closeArchPlanModal() {
        this.showArchPlanModal = false;
        this.isArchSending = false;
    }

    onArchDateTimeChange(event) { this.archPlanDateTime = event.target.value; }
    onArchDurationChange(event) { this.archPlanDuration = event.target.value; }

    confirmArchSchedule() {
        if (!this.archPlanDateTime) {
            this.showToast('⚠️ Veuillez choisir une date et heure.', 'error');
            return;
        }
        this.isArchSending = true;
        scheduleArchitectureInterview({
            oppId:             this.archPlanOppId,
            interviewDateTime: this.archPlanDateTime,
            duration:          this.archPlanDuration
        })
        .then(result => {
            this.showArchPlanModal = false;
            this.isArchSending = false;
            this.showToast('✅ Entretien architecture planifié ! Lien Jitsi auto-généré.', 'success');
            this.allOpps = this.allOpps.map(o => {
                if (o.Id === this.archPlanOppId) {
                    return this.mapOpp({
                        ...o,
                        archDateTime:  this.archPlanDateTime,
                        archDuration:  this.archPlanDuration,
                        archMeetLink:  result.jitsiUrl,
                        archJitsiRoom: result.jitsiRoom,
                        archStatus:    'Scheduled',
                        archRescheduleRequested: false
                    });
                }
                return o;
            });
            this.applyFilter();
        })
        .catch(err => {
            this.isArchSending = false;
            this.showToast('❌ Erreur : ' + (err.body ? err.body.message : err.message), 'error');
        });
    }

    // ── Batch planning ──
    // RH Fit interview planning
    openRHFitPlanModal(event) {
        this.rhfitPlanOppId = event.currentTarget.dataset.id;
        this.rhfitPlanCandidatName = event.currentTarget.dataset.name;
        this.rhfitPlanDuration = '45';
        const now = new Date();
        const pad = n => String(n).padStart(2, '0');
        this.rhfitPlanDateTime = `${now.getFullYear()}-${pad(now.getMonth()+1)}-${pad(now.getDate())}T${pad(now.getHours())}:${pad(now.getMinutes())}`;
        this.showRHFitPlanModal = true;
    }

    closeRHFitPlanModal() {
        this.showRHFitPlanModal = false;
        this.isRHFitSending = false;
    }

    onRHFitDateTimeChange(event) { this.rhfitPlanDateTime = event.target.value; }
    onRHFitDurationChange(event) { this.rhfitPlanDuration = event.target.value; }

    confirmRHFitSchedule() {
        if (!this.rhfitPlanDateTime) {
            this.showToast('Veuillez choisir une date et heure.', 'error');
            return;
        }
        this.isRHFitSending = true;
        scheduleRHFitInterview({
            oppId: this.rhfitPlanOppId,
            interviewDateTime: this.rhfitPlanDateTime,
            duration: this.rhfitPlanDuration
        })
            .then(() => this.refreshDashboardData())
            .then(() => {
                this.showRHFitPlanModal = false;
                this.isRHFitSending = false;
                this.showToast('Invitation RH Fit envoyee avec succes.', 'success');
            })
            .catch(err => {
                this.isRHFitSending = false;
                this.showToast('Erreur RH Fit : ' + (err.body ? err.body.message : err.message), 'error');
            });
    }

    handleRHFitPrimaryAction(event) {
        const id = event.currentTarget.dataset.id;
        const name = event.currentTarget.dataset.name || '';
        const action = event.currentTarget.dataset.action;
        this.runRHFitAction(action, id, name);
    }

    handleRHFitSecondaryAction(event) {
        const id = event.currentTarget.dataset.id;
        const name = event.currentTarget.dataset.name || '';
        const action = event.detail ? event.detail.value : '';
        this.runRHFitAction(action, id, name);
    }

    runRHFitAction(action, id, name = '') {
        if (!id || !action) return;
        const actionEvent = { currentTarget: { dataset: { id, name } } };
        switch (action) {
            case 'plan':
            case 'replan':
                this.openRHFitPlanModal(actionEvent);
                break;
            case 'process':
                this.openRHFitProcessModal(actionEvent);
                break;
            case 'validate':
                this.openRHFitValidationModal(actionEvent);
                break;
            case 'questions':
                this.openRHFitQuestionModal(actionEvent);
                break;
            case 'assistant':
                this.handleRescore(actionEvent);
                break;
            case 'report':
            case 'dossier':
                this.openDetailModal(actionEvent);
                break;
            default:
                break;
        }
    }

    toggleSelect(event) {
        const id = event.currentTarget.dataset.id;
        const updated = Object.assign({}, this.selectedMap);
        if (updated[id]) {
            delete updated[id];
        } else {
            updated[id] = true;
        }
        this.selectedMap = updated;
        this.allOpps = this.allOpps.map(o => this.mapOpp(o));
        this.applyFilter();
    }

    toggleSelectAll() {
        const gamingOpps = this.filteredOpps.filter(o => o.isGaming);
        const allSelected = gamingOpps.length > 0 && gamingOpps.every(o => !!this.selectedMap[o.Id]);
        const updated = Object.assign({}, this.selectedMap);
        if (allSelected) {
            gamingOpps.forEach(o => { delete updated[o.Id]; });
        } else {
            gamingOpps.forEach(o => { updated[o.Id] = true; });
        }
        this.selectedMap = updated;
        this.allOpps = this.allOpps.map(o => this.mapOpp(o));
        this.applyFilter();
    }

    get selectedCount() {
        return Object.keys(this.selectedMap).length;
    }

    get hasSelected() {
        return Object.keys(this.selectedMap).length > 0;
    }

    get isAllGamingSelected() {
        const gamingOpps = this.filteredOpps.filter(o => o.isGaming);
        return gamingOpps.length > 0 && gamingOpps.every(o => !!this.selectedMap[o.Id]);
    }

    get selectAllCheckClass() {
        return 'batch-checkbox' + (this.isAllGamingSelected ? ' checked' : '');
    }

    openBatchModal() {
        if (Object.keys(this.selectedMap).length === 0) {
            this.showToast('⚠️ Sélectionnez au moins un candidat Gaming.', 'error');
            return;
        }
        this.batchDuration = '60';
        this.batchGap = '30';
        // défaut = heure système actuelle
        const now = new Date();
        const pad = n => String(n).padStart(2, '0');
        this.batchDateTime = `${now.getFullYear()}-${pad(now.getMonth()+1)}-${pad(now.getDate())}T${pad(now.getHours())}:${pad(now.getMinutes())}`;
        this.updateBatchPreview();
        this.showBatchModal = true;
    }

    closeBatchModal() {
        this.showBatchModal = false;
        this.isBatchSending = false;
    }

    onBatchDateTimeChange(event) {
        this.batchDateTime = event.target.value;
        this.updateBatchPreview();
    }
    onBatchDurationChange(event) {
        this.batchDuration = event.target.value;
        this.updateBatchPreview();
    }
    onBatchGapChange(event) {
        this.batchGap = event.target.value;
        this.updateBatchPreview();
    }

    updateBatchPreview() {
        if (!this.batchDateTime) {
            this.batchPreview = [];
            return;
        }
        const startDt = new Date(this.batchDateTime);
        const slotMin = parseInt(this.batchDuration, 10) + parseInt(this.batchGap, 10);
        const selectedOpps = this.allOpps.filter(o => !!this.selectedMap[o.Id]);
        this.batchPreview = selectedOpps.map((o, i) => {
            const slot = new Date(startDt.getTime() + i * slotMin * 60000);
            return {
                id: o.Id,
                name: o.Name,
                initials: o.initials,
                timeFmt: slot.toLocaleDateString('fr-FR') + ' à ' + slot.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })
            };
        });
    }

    get batchSummary() {
        const n = Object.keys(this.selectedMap).length;
        const dur = parseInt(this.batchDuration, 10);
        const gap = parseInt(this.batchGap, 10);
        const totalMin = n * dur + (n - 1) * gap;
        const h = Math.floor(totalMin / 60);
        const m = totalMin % 60;
        return `${n} candidat${n > 1 ? 's' : ''} · Durée totale : ${h > 0 ? h + 'h' : ''}${m > 0 ? m + 'min' : ''}`;
    }

    confirmBatchSchedule() {
        if (!this.batchDateTime) {
            this.showToast('⚠️ Veuillez choisir une date et heure de début.', 'error');
            return;
        }
        this.isBatchSending = true;
        const oppIds = Object.keys(this.selectedMap);
        scheduleBatchGamingTests({
            oppIds,
            startDateTime: this.batchDateTime,
            duration: this.batchDuration,
            gapMinutes: parseInt(this.batchGap, 10)
        })
        .then(results => {
            this.showBatchModal = false;
            this.isBatchSending = false;
            // Mettre à jour localement
            const resultMap = {};
            results.forEach(r => { resultMap[r.oppId] = r; });
            this.allOpps = this.allOpps.map(o => {
                const r = resultMap[o.Id];
                if (r) {
                    return this.mapOpp({
                        ...o,
                        gamingDateTime: r.dateTime,
                        gamingDuration: this.batchDuration,
                        gamingMeetLink: r.meetLink
                    });
                }
                return o;
            });
            this.selectedMap = {};
            this.allOpps = this.allOpps.map(o => this.mapOpp(o));
            this.applyFilter();
            this.showToast(`✅ ${results.length} invitation${results.length > 1 ? 's' : ''} envoyée${results.length > 1 ? 's' : ''} avec succès !`, 'success');
        })
        .catch(err => {
            this.isBatchSending = false;
            this.showToast('❌ Erreur : ' + (err.body ? err.body.message : err.message), 'error');
        });
    }

    showToast(msg, type) {
        this.toastMessage = msg;
        this.toastClass = 'rdb-toast toast-' + type;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.toastMessage = ''; }, 4000);
    }

    // ── KPI bar widths ──
    get gamingBarStyle()       { return this.barStyle(this.enGaming); }
    get techniqueBarStyle()    { return this.barStyle(this.enTechnique); }
    get architectureBarStyle() { return this.barStyle(this.enArchitecture); }
    get rhfitBarStyle()        { return this.barStyle(this.enRHFit); }
    get closedBarStyle()       { return this.barStyle(this.closedCount); }

    barStyle(val) {
        const pct = this.totalCandidats > 0 ? Math.round((val / this.totalCandidats) * 100) : 0;
        return `width:${pct}%`;
    }

    // ── Filter chip classes ──
    get chipAll()          { return this.chipClass(''); }
    get chipGaming()       { return this.chipClass('Gaming'); }
    get chipTechnique()    { return this.chipClass('Technique'); }
    get chipArchitecture() { return this.chipClass('Architecture'); }
    get chipRHFit()        { return this.chipClass('RH Fit'); }
    get chipClosed()       { return this.chipClass('Closed'); }

    chipClass(s) { return 'filter-chip' + (this.activeStage === s ? ' chip-active' : ''); }

    get hasFiltered()  { return this.filteredOpps.length > 0; }
    get filteredCount(){ return this.filteredOpps.length; }

    // ══════════════════════════════════════
    // TAB SWITCHING
    // ══════════════════════════════════════

    switchTab(event) {
        this.activeTab = event.currentTarget.dataset.tab;
        if (this.activeTab === 'offres' && this.jobPostings.length === 0) {
            this.loadJobPostings();
        }
    }

    // ══════════════════════════════════════
    // JOB POSTINGS
    // ══════════════════════════════════════

    loadJobPostings() {
        getJobPostings()
            .then(data => {
                this.jobPostings = (data || []).map(j => {
                    const created = j.CreatedDate ? new Date(j.CreatedDate) : null;
                    return {
                        ...j,
                        createdFmt: created ? created.toLocaleDateString('fr-FR') : '',
                        statusLabel: j.IsClosed ? 'Clôturée' : 'Active',
                        statusClass: j.IsClosed ? 'offer-status offer-closed' : 'offer-status offer-active'
                    };
                });
                this.totalOffres = this.jobPostings.filter(j => !j.IsClosed).length;
            })
            .catch(err => {
                this.showToast('Erreur chargement offres : ' + (err.body ? err.body.message : err.message), 'error');
            });
    }

    openCreateOfferModal() {
        this.offerTitle = '';
        this.offerDepartment = '';
        this.offerLocation = '';
        this.offerContract = '';
        this.offerSalary = '';
        this.offerDescription = '';
        // Close date = +30 jours
        const d = new Date();
        d.setDate(d.getDate() + 30);
        const pad = n => String(n).padStart(2, '0');
        this.offerCloseDate = `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}`;
        this.showCreateOfferModal = true;
    }

    closeCreateOfferModal() {
        this.showCreateOfferModal = false;
        this.isCreatingOffer = false;
    }

    onOfferTitleChange(e) { this.offerTitle = e.target.value; }
    onOfferDeptChange(e) { this.offerDepartment = e.target.value; }
    onOfferLocChange(e) { this.offerLocation = e.target.value; }
    onOfferContractChange(e) { this.offerContract = e.target.value; }
    onOfferSalaryChange(e) { this.offerSalary = e.target.value; }
    onOfferDescChange(e) { this.offerDescription = e.target.value; }
    onOfferCloseDateChange(e) { this.offerCloseDate = e.target.value; }

    generateAIDescription() {
        if (!this.offerTitle) {
            this.showToast('Veuillez remplir au moins le titre du poste.', 'error');
            return;
        }
        this.isGeneratingDesc = true;
        generateJobDescription({
            title: this.offerTitle,
            department: this.offerDepartment,
            location: this.offerLocation,
            contractType: this.offerContract,
            salary: this.offerSalary ? parseFloat(this.offerSalary) : null,
            rawDescription: this.offerDescription
        })
        .then(result => {
            this.offerDescription = result;
            this.isGeneratingDesc = false;
            // Force textarea DOM update (native textarea ignores tracked value after user interaction)
            const ta = this.template.querySelector('.form-textarea');
            if (ta) { ta.value = result; }
            this.showToast('Description générée par l\'IA !', 'success');
        })
        .catch(err => {
            this.isGeneratingDesc = false;
            this.showToast('Erreur IA : ' + (err.body ? err.body.message : err.message), 'error');
        });
    }

    confirmCreateOffer() {
        if (!this.offerTitle || !this.offerDepartment || !this.offerLocation || !this.offerContract) {
            this.showToast('Veuillez remplir tous les champs obligatoires.', 'error');
            return;
        }
        this.isCreatingOffer = true;
        createJobPosting({
            title: this.offerTitle,
            department: this.offerDepartment,
            location: this.offerLocation,
            contractType: this.offerContract,
            salary: this.offerSalary ? parseFloat(this.offerSalary) : null,
            description: this.offerDescription,
            closeDate: this.offerCloseDate
        })
        .then(() => {
            this.showCreateOfferModal = false;
            this.isCreatingOffer = false;
            this.showToast('Offre publiée avec succès !', 'success');
            this.loadJobPostings();
        })
        .catch(err => {
            this.isCreatingOffer = false;
            this.showToast('Erreur : ' + (err.body ? err.body.message : err.message), 'error');
        });
    }

    closeJobPosting(event) {
        const id = event.currentTarget.dataset.id;
        toggleJobPosting({ jobId: id, close: true })
            .then(() => {
                this.showToast('Offre clôturée.', 'success');
                this.loadJobPostings();
            })
            .catch(err => {
                this.showToast('Erreur : ' + (err.body ? err.body.message : err.message), 'error');
            });
    }

    reopenJobPosting(event) {
        const id = event.currentTarget.dataset.id;
        toggleJobPosting({ jobId: id, close: false })
            .then(() => {
                this.showToast('Offre réouverte.', 'success');
                this.loadJobPostings();
            })
            .catch(err => {
                this.showToast('Erreur : ' + (err.body ? err.body.message : err.message), 'error');
            });
    }

    /* ═══════ GAMING QUESTIONS — IA Generation ═══════ */
    generateGamingQuestions(event) {
        const jobId = event.currentTarget.dataset.id;
        if (!jobId) return;
        this.showToast('Génération IA des questions gaming en cours...', 'info');
        generateGamingQuestionsApex({ jobPostingId: jobId })
            .then(() => {
                // Poll for completion
                this._pollGamingStatus(jobId, 0);
            })
            .catch(err => {
                this.showToast('Erreur : ' + (err.body ? err.body.message : err.message), 'error');
            });
    }

    _pollGamingStatus(jobId, attempt) {
        if (attempt > 15) {
            this.showToast('Génération en cours en arrière-plan. Rafraîchissez dans quelques instants.', 'info');
            return;
        }
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            getGenerationStatus({ jobPostingId: jobId })
                .then(result => {
                    if (result.ready) {
                        this.showToast(`${result.count} questions gaming générées par l\'IA !`, 'success');
                    } else {
                        this._pollGamingStatus(jobId, attempt + 1);
                    }
                })
                .catch(() => {
                    this._pollGamingStatus(jobId, attempt + 1);
                });
        }, 3000);
    }

    /* ═══════ TECHNICAL QUESTIONS — IA Generation ═══════ */
    generateTechQuestions(event) {
        const jobId = event.currentTarget.dataset.id;
        if (!jobId) return;
        this.showToast('Génération IA des exercices techniques en cours...', 'info');
        generateTechQuestionsApex({ jobPostingId: jobId })
            .then(() => {
                this._pollTechStatus(jobId, 0);
            })
            .catch(err => {
                this.showToast('Erreur : ' + (err.body ? err.body.message : err.message), 'error');
            });
    }

    _pollTechStatus(jobId, attempt) {
        if (attempt > 20) {
            this.showToast('Génération en cours en arrière-plan. Rafraîchissez dans quelques instants.', 'info');
            return;
        }
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            getTechGenerationStatus({ jobPostingId: jobId })
                .then(result => {
                    if (result.ready) {
                        this.showToast(`${result.count} exercices techniques générés par l\'IA !`, 'success');
                    } else {
                        this._pollTechStatus(jobId, attempt + 1);
                    }
                })
                .catch(() => {
                    this._pollTechStatus(jobId, attempt + 1);
                });
        }, 3000);
    }

    // ══════════════════════════════════════
    // DETAIL MODAL
    // ══════════════════════════════════════

    openDetailModal(event) {
        const id = event.currentTarget.dataset.id;
        this.detailOpp = this.allOpps.find(o => o.Id === id) || {};
        this.showDetailModal = true;
    }

    closeDetailModal() {
        this.showDetailModal = false;
    }

    // ══════════════════════════════════════
    // TECH INTERVIEW VALIDATION
    // ══════════════════════════════════════

    // RH Fit question generation
    openRHFitQuestionModal(event) {
        let id = null;
        if (event && event.currentTarget && event.currentTarget.dataset) {
            id = event.currentTarget.dataset.id;
        }
        if (!id && this.detailOpp) {
            id = this.detailOpp.Id;
        }
        if (!id) return;
        const opp = this.allOpps.find(o => o.Id === id) || this.detailOpp || {};
        this.rhfitQuestionOppId = id;
        this.rhfitQuestionCandidateName = opp.Name || '';
        this.rhfitQuestionsText = opp.rhfitQuestions || '';
        this.showRHFitQuestionModal = true;
    }

    get hasRHFitQuestionsText() {
        return !!(this.rhfitQuestionsText && this.rhfitQuestionsText.trim().length > 0);
    }

    get rhfitQuestionsDisplayJson() {
        if (!this.hasRHFitQuestionsText) return '';
        const parsed = this.tryParseRHFitQuestions(this.rhfitQuestionsText);
        if (parsed == null) return this.rhfitQuestionsText;
        try {
            return JSON.stringify(parsed, null, 2);
        } catch (e) {
            return this.rhfitQuestionsText;
        }
    }

    get rhfitInterviewIntro() {
        const parsed = this.tryParseRHFitQuestions(this.rhfitQuestionsText);
        if (!parsed || Array.isArray(parsed) || typeof parsed !== 'object') return '';
        return this.readFirstString(parsed, ['interview_intro', 'intro', 'summary', 'guide_intro']);
    }

    get rhfitQuestionCards() {
        const parsed = this.tryParseRHFitQuestions(this.rhfitQuestionsText);
        const source = this.extractRHFitQuestionSource(parsed);
        return source
            .map((item, index) => this.normalizeRHFitQuestionItem(item, index))
            .filter(item => item.question)
            .map((item, index) => ({
                ...item,
                key: `${item.id}-${index}`,
                displayIndex: index + 1
            }));
    }

    get hasRHFitQuestionCards() {
        return this.rhfitQuestionCards.length > 0;
    }

    closeRHFitQuestionModal() {
        this.showRHFitQuestionModal = false;
        this.isGeneratingRHFitQuestions = false;
    }

    generateRHFitQuestions() {
        if (!this.rhfitQuestionOppId || this.isGeneratingRHFitQuestions) return;
        this.isGeneratingRHFitQuestions = true;
        generateRHFitQuestionsApex({ oppId: this.rhfitQuestionOppId })
            .then(result => {
                const payload = result && (result.questions || result.promptResponse || result.response);
                const generated = typeof payload === 'string'
                    ? payload
                    : (payload ? JSON.stringify(payload) : '');
                this.rhfitQuestionsText = generated;
                this.allOpps = this.allOpps.map(o => (
                    o.Id === this.rhfitQuestionOppId
                        ? this.mapOpp({ ...o, rhfitQuestions: this.rhfitQuestionsText })
                        : o
                ));
                this.applyFilter();
                if (this.detailOpp && this.detailOpp.Id === this.rhfitQuestionOppId) {
                    this.detailOpp = this.allOpps.find(o => o.Id === this.rhfitQuestionOppId) || this.detailOpp;
                }
                if (this.rhfitQuestionsText && this.rhfitQuestionsText.trim().length > 0) {
                    this.showToast('Questions RH Fit generees par Einstein.', 'success');
                } else {
                    this.showToast('Einstein a repondu vide. Verifie le Prompt Template.', 'error');
                }
            })
            .catch(err => {
                this.showToast('Erreur Einstein RH Fit : ' + (err.body ? err.body.message : err.message), 'error');
            })
            .finally(() => {
                this.isGeneratingRHFitQuestions = false;
            });
    }

    // RH Fit recruiter processing (audio -> transcription -> IA)
    openRHFitProcessModal(event) {
        let id = null;
        if (event && event.currentTarget && event.currentTarget.dataset) {
            id = event.currentTarget.dataset.id;
        }
        if (!id && this.detailOpp) {
            id = this.detailOpp.Id;
        }
        if (!id) return;

        const opp = this.allOpps.find(o => o.Id === id) || this.detailOpp || {};
        if (!opp.rhfitScheduled) {
            this.showToast('Entretien RH Fit non planifie pour ce candidat.', 'error');
            return;
        }

        this.rhfitProcessOppId = id;
        this.rhfitProcessCandidateName = opp.Name || '';
        this.rhfitProcessStatus = opp.rhfitStatus || 'Scheduled';
        const initialStatusLower = (opp.rhfitStatus || '').toLowerCase();
        this.rhfitProcessHasAudio = !!opp.rhfitHasAudio || initialStatusLower.includes('audio') || initialStatusLower.includes('processing') || initialStatusLower.includes('completed');
        this.rhfitProcessAIScore = opp.rhfitAIScore != null ? opp.rhfitAIScore : null;
        this.rhfitProcessSentimentScore = opp.rhfitSentimentScore != null ? opp.rhfitSentimentScore : null;
        this.rhfitProcessSentimentLabel = opp.rhfitSentimentLabel || '';
        this.rhfitProcessTranscription = '';
        this.rhfitProcessAIFeedback = '';
        this.rhfitProcessFileName = '';
        this.rhfitSelectedAudioFile = null;
        this.isRHFitUploadingAudio = false;
        this.isRHFitProcessingAudio = false;
        this.showRHFitProcessModal = true;

        getRHFitProcessingStatusApex({ oppId: this.rhfitProcessOppId })
            .then(result => {
                this.rhfitProcessStatus = result.status || this.rhfitProcessStatus;
                this.rhfitProcessAIScore = result.score != null ? Math.round(result.score) : this.rhfitProcessAIScore;
                this.rhfitProcessSentimentScore = result.sentimentScore != null
                    ? Math.round(result.sentimentScore * 100) / 100
                    : this.rhfitProcessSentimentScore;
                this.rhfitProcessSentimentLabel = result.sentimentLabel || this.rhfitProcessSentimentLabel;
                this.rhfitProcessTranscription = result.transcription || '';
                this.rhfitProcessAIFeedback = result.aiFeedback || '';
                this.syncRHFitProcessToOpp({
                    rhfitStatus: this.rhfitProcessStatus,
                    rhfitAIScore: this.rhfitProcessAIScore,
                    rhfitSentimentScore: this.rhfitProcessSentimentScore,
                    rhfitSentimentLabel: this.rhfitProcessSentimentLabel
                });
            })
            .catch(() => {});

        const statusLower = (this.rhfitProcessStatus || '').toLowerCase();
        if (statusLower.includes('processing')) {
            this.isRHFitProcessingAudio = true;
            this.startRHFitProcessingPolling();
        }
    }

    closeRHFitProcessModal() {
        this.stopRHFitProcessingPolling();
        this.showRHFitProcessModal = false;
        this.isRHFitUploadingAudio = false;
        this.isRHFitProcessingAudio = false;
        this.rhfitSelectedAudioFile = null;
        this.rhfitProcessFileName = '';
        this.rhfitProcessHasAudio = false;
    }

    stopPropagationRHFitProcess(event) {
        event.stopPropagation();
    }

    get rhfitProcessHasAIScore() {
        return this.rhfitProcessAIScore != null;
    }

    get rhfitProcessHasSentimentScore() {
        return this.rhfitProcessSentimentScore != null;
    }

    get rhfitProcessHasTranscription() {
        return !!(this.rhfitProcessTranscription && this.rhfitProcessTranscription.trim().length > 0);
    }

    get rhfitProcessHasFeedback() {
        return !!(this.rhfitProcessAIFeedback && this.rhfitProcessAIFeedback.trim().length > 0);
    }

    get rhfitProcessCanUploadAudio() {
        return !!this.rhfitSelectedAudioFile && !this.isRHFitUploadingAudio && !this.isRHFitProcessingAudio;
    }

    get rhfitProcessCanStartAI() {
        return this.rhfitProcessHasAudio && !this.isRHFitUploadingAudio && !this.isRHFitProcessingAudio;
    }

    get rhfitProcessUploadDisabled() {
        return !this.rhfitProcessCanUploadAudio;
    }

    get rhfitProcessStartDisabled() {
        return !this.rhfitProcessCanStartAI;
    }

    get rhfitProcessStatusClass() {
        const s = (this.rhfitProcessStatus || '').toLowerCase();
        if (s.includes('completed')) return 'rhfit-process-pill rhfit-process-success';
        if (s.includes('processing')) return 'rhfit-process-pill rhfit-process-info';
        if (s.includes('error')) return 'rhfit-process-pill rhfit-process-danger';
        if (s.includes('audio')) return 'rhfit-process-pill rhfit-process-warn';
        return 'rhfit-process-pill rhfit-process-neutral';
    }

    onRHFitProcessFileChange(event) {
        const file = event.target.files && event.target.files[0];
        if (!file) return;
        const maxBytes = 24 * 1024 * 1024;
        if (!file.size || file.size <= 0) {
            this.showToast('Fichier audio vide. Merci de choisir un enregistrement valide.', 'error');
            return;
        }
        if (file.size > maxBytes) {
            this.showToast('Audio trop volumineux. Taille max: 24 MB.', 'error');
            return;
        }
        const fileName = String(file.name || '').toLowerCase();
        const ext = fileName.includes('.') ? fileName.split('.').pop() : '';
        const allowedExt = ['webm', 'mp3', 'wav', 'm4a', 'ogg', 'flac'];
        if (!allowedExt.includes(ext)) {
            this.showToast('Format non supporte. Utilisez: .webm, .mp3, .wav, .m4a, .ogg, .flac', 'error');
            return;
        }
        this.rhfitSelectedAudioFile = file;
        this.rhfitProcessFileName = file.name;
    }

    readFileAsBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => {
                const value = String(reader.result || '');
                const idx = value.indexOf(',');
                resolve(idx >= 0 ? value.substring(idx + 1) : value);
            };
            reader.onerror = () => reject(new Error('Lecture du fichier audio impossible.'));
            reader.readAsDataURL(file);
        });
    }

    uploadRHFitAudioForProcess() {
        if (!this.rhfitProcessCanUploadAudio || !this.rhfitProcessOppId) return;

        this.isRHFitUploadingAudio = true;
        this.readFileAsBase64(this.rhfitSelectedAudioFile)
            .then(base64 => uploadRHFitAudioApex({
                oppId: this.rhfitProcessOppId,
                audioBase64: base64,
                fileName: this.rhfitProcessFileName || `rhfit-interview-${Date.now()}.webm`
            }))
            .then(() => {
                this.rhfitProcessStatus = 'Audio Uploaded';
                this.rhfitProcessHasAudio = true;
                this.syncRHFitProcessToOpp({
                    rhfitStatus: 'Audio Uploaded',
                    rhfitHasAudio: true
                });
                this.showToast('Audio RH Fit uploade.', 'success');
            })
            .catch(err => {
                this.showToast('Erreur upload audio RH Fit : ' + (err.body ? err.body.message : err.message), 'error');
            })
            .finally(() => {
                this.isRHFitUploadingAudio = false;
            });
    }

    startRHFitAIProcessing() {
        if (!this.rhfitProcessCanStartAI || !this.rhfitProcessOppId) return;

        this.isRHFitProcessingAudio = true;
        this.rhfitProcessStatus = 'Processing';
        processRHFitAudioApex({ oppId: this.rhfitProcessOppId })
            .then(() => {
                this.syncRHFitProcessToOpp({ rhfitStatus: 'Processing' });
                this.startRHFitProcessingPolling();
                this.showToast('Transcription + analyse RH Fit lancees.', 'info');
            })
            .catch(err => {
                this.isRHFitProcessingAudio = false;
                this.rhfitProcessStatus = 'Error';
                this.showToast('Erreur lancement analyse RH Fit : ' + (err.body ? err.body.message : err.message), 'error');
            });
    }

    startRHFitProcessingPolling() {
        this.stopRHFitProcessingPolling();
        this.rhfitProcessPollingAttempts = 0;
        this.pollRHFitProcessing();
    }

    stopRHFitProcessingPolling() {
        if (this.rhfitProcessPollingTimer) {
            clearTimeout(this.rhfitProcessPollingTimer);
            this.rhfitProcessPollingTimer = null;
        }
    }

    pollRHFitProcessing() {
        if (!this.rhfitProcessOppId) return;
        this.rhfitProcessPollingAttempts += 1;

        getRHFitProcessingStatusApex({ oppId: this.rhfitProcessOppId })
            .then(result => {
                const status = result.status || this.rhfitProcessStatus || '';
                this.rhfitProcessStatus = status;
                this.rhfitProcessAIScore = result.score != null ? Math.round(result.score) : this.rhfitProcessAIScore;
                this.rhfitProcessSentimentScore = result.sentimentScore != null
                    ? Math.round(result.sentimentScore * 100) / 100
                    : this.rhfitProcessSentimentScore;
                this.rhfitProcessSentimentLabel = result.sentimentLabel || this.rhfitProcessSentimentLabel;
                this.rhfitProcessTranscription = result.transcription || this.rhfitProcessTranscription;
                this.rhfitProcessAIFeedback = result.aiFeedback || this.rhfitProcessAIFeedback;

                this.syncRHFitProcessToOpp({
                    rhfitStatus: status,
                    rhfitAIScore: this.rhfitProcessAIScore,
                    rhfitSentimentScore: this.rhfitProcessSentimentScore,
                    rhfitSentimentLabel: this.rhfitProcessSentimentLabel
                });

                const statusLower = status.toLowerCase();
                if (statusLower.includes('audio') || statusLower.includes('processing') || statusLower.includes('completed')) {
                    this.rhfitProcessHasAudio = true;
                }
                if (result.isComplete || statusLower.includes('completed')) {
                    this.isRHFitProcessingAudio = false;
                    this.stopRHFitProcessingPolling();
                    this.showToast('Analyse RH Fit terminee.', 'success');
                    return;
                }
                if (statusLower.includes('error')) {
                    this.isRHFitProcessingAudio = false;
                    this.stopRHFitProcessingPolling();
                    this.showToast('Traitement RH Fit en erreur.', 'error');
                    return;
                }

                if (this.rhfitProcessPollingAttempts >= 60) {
                    this.isRHFitProcessingAudio = false;
                    this.stopRHFitProcessingPolling();
                    this.showToast('Le traitement RH Fit prend plus de temps que prevu.', 'info');
                    return;
                }

                // eslint-disable-next-line @lwc/lwc/no-async-operation
                this.rhfitProcessPollingTimer = setTimeout(() => this.pollRHFitProcessing(), 4000);
            })
            .catch(() => {
                if (this.rhfitProcessPollingAttempts >= 60) {
                    this.isRHFitProcessingAudio = false;
                    this.stopRHFitProcessingPolling();
                    this.showToast('Impossible de recuperer le statut RH Fit.', 'error');
                    return;
                }
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                this.rhfitProcessPollingTimer = setTimeout(() => this.pollRHFitProcessing(), 4000);
            });
    }

    syncRHFitProcessToOpp(fields) {
        this.allOpps = this.allOpps.map(o => (
            o.Id === this.rhfitProcessOppId ? this.mapOpp({ ...o, ...fields }) : o
        ));
        this.applyFilter();
        if (this.detailOpp && this.detailOpp.Id === this.rhfitProcessOppId) {
            this.detailOpp = this.allOpps.find(o => o.Id === this.rhfitProcessOppId) || this.detailOpp;
        }
    }

    tryParseRHFitQuestions(raw) {
        if (!raw || !raw.trim()) return null;
        const direct = this.parseJson(raw.trim());
        if (direct != null) return direct;

        const withoutFence = this.stripCodeFence(raw.trim());
        const fenced = this.parseJson(withoutFence);
        if (fenced != null) return fenced;

        const jsonBlock = this.extractJsonBlock(withoutFence);
        if (!jsonBlock) return null;
        return this.parseJson(jsonBlock);
    }

    parseJson(text) {
        if (!text) return null;
        try {
            return JSON.parse(text);
        } catch (e) {
            return null;
        }
    }

    stripCodeFence(text) {
        if (!text) return '';
        let value = text;
        value = value.replace(/^```json\s*/i, '');
        value = value.replace(/^```\s*/i, '');
        value = value.replace(/\s*```$/i, '');
        return value.trim();
    }

    extractJsonBlock(text) {
        if (!text) return '';
        const firstObj = text.indexOf('{');
        const firstArr = text.indexOf('[');
        let start = -1;

        if (firstObj >= 0 && firstArr >= 0) {
            start = Math.min(firstObj, firstArr);
        } else {
            start = firstObj >= 0 ? firstObj : firstArr;
        }
        if (start < 0) return '';

        const openChar = text[start];
        const closeChar = openChar === '{' ? '}' : ']';
        const end = text.lastIndexOf(closeChar);
        if (end <= start) return '';

        return text.substring(start, end + 1).trim();
    }

    extractRHFitQuestionSource(parsed) {
        if (!parsed) return [];
        if (Array.isArray(parsed)) return parsed;
        if (typeof parsed !== 'object') return [];

        const directArrayKeys = ['questions', 'interview_questions', 'rhfit_questions', 'question_set'];
        for (const key of directArrayKeys) {
            if (Array.isArray(parsed[key])) {
                return parsed[key];
            }
        }

        const gathered = [];
        for (const key of Object.keys(parsed)) {
            const keyLower = key.toLowerCase();
            const value = parsed[key];
            if (Array.isArray(value) && keyLower.includes('question')) {
                gathered.push(...value);
            } else if ((keyLower.startsWith('question') || keyLower.startsWith('q')) && typeof value === 'string') {
                gathered.push({ id: key, question: value });
            }
        }

        return gathered;
    }

    normalizeRHFitQuestionItem(item, index) {
        if (typeof item === 'string') {
            return {
                id: String(index + 1),
                question: item.trim(),
                intent: '',
                followUp: ''
            };
        }
        if (!item || typeof item !== 'object') {
            return {
                id: String(index + 1),
                question: '',
                intent: '',
                followUp: ''
            };
        }

        const id = this.readFirstString(item, ['id', 'number', 'index', 'code']) || String(index + 1);
        const question = this.readFirstString(item, ['question', 'text', 'prompt', 'content', 'title']);
        const intent = this.readFirstString(item, ['intent', 'objective', 'goal', 'competency', 'evaluation_focus']);
        const followUp = this.readFirstString(item, ['follow_up', 'followUp', 'relance', 'probe', 'dig_deeper']);

        return {
            id,
            question,
            intent,
            followUp
        };
    }

    readFirstString(source, keys) {
        if (!source || typeof source !== 'object' || !Array.isArray(keys)) return '';
        for (const key of keys) {
            if (Object.prototype.hasOwnProperty.call(source, key) && source[key] != null) {
                const rawValue = source[key];
                let value = '';
                if (Array.isArray(rawValue)) {
                    value = rawValue
                        .map(item => (item == null ? '' : String(item).trim()))
                        .filter(item => item.length > 0)
                        .join(' | ');
                } else if (typeof rawValue === 'object') {
                    try {
                        value = JSON.stringify(rawValue);
                    } catch (e) {
                        value = '';
                    }
                } else {
                    value = String(rawValue).trim();
                }
                if (value) return value;
            }
        }
        return '';
    }

    // RH Fit validation
    openRHFitValidationModal(event) {
        let id = null;
        if (event && event.currentTarget && event.currentTarget.dataset) {
            id = event.currentTarget.dataset.id;
        }
        if (!id && this.detailOpp) {
            id = this.detailOpp.Id;
        }
        if (!id) return;
        const opp = this.allOpps.find(o => o.Id === id) || this.detailOpp;
        if (!opp || !opp.rhfitScheduled) {
            this.showToast('Entretien RH Fit non planifie pour ce candidat.', 'error');
            return;
        }
        this.rhfitValidationOppId = id;
        this.rhfitValidationCandidateName = opp.Name || '';
        this.rhfitValidationAIScore = opp.rhfitAIScore != null ? opp.rhfitAIScore : 0;
        this.rhfitValidationSentiment = opp.rhfitSentimentLabel || 'N/A';
        this.rhfitValidationScore = opp.rhfitValidatedScore != null
            ? opp.rhfitValidatedScore
            : (opp.rhfitAIScore != null ? opp.rhfitAIScore : 0);
        this.rhfitValidationDecision = '';
        this.rhfitValidationNotes = '';
        this.showRHFitValidationModal = true;
    }

    closeRHFitValidationModal() {
        this.showRHFitValidationModal = false;
        this.isRHFitValidating = false;
    }

    stopPropagationRHFitValidation(event) {
        event.stopPropagation();
    }

    onRHFitValidationScoreChange(event) {
        this.rhfitValidationScore = parseInt(event.target.value, 10) || 0;
    }

    onRHFitValidationNotesChange(event) {
        this.rhfitValidationNotes = event.target.value;
    }

    setRHFitDecisionAccept() { this.rhfitValidationDecision = 'accept'; }
    setRHFitDecisionReview() { this.rhfitValidationDecision = 'review'; }
    setRHFitDecisionReject() { this.rhfitValidationDecision = 'reject'; }

    get btnRHFitAcceptClass() {
        return 'btn-decision btn-accept' + (this.rhfitValidationDecision === 'accept' ? ' decision-active' : '');
    }

    get btnRHFitReviewClass() {
        return 'btn-decision btn-review' + (this.rhfitValidationDecision === 'review' ? ' decision-active' : '');
    }

    get btnRHFitRejectClass() {
        return 'btn-decision btn-reject' + (this.rhfitValidationDecision === 'reject' ? ' decision-active' : '');
    }

    get rhfitCannotSubmit() {
        return !this.rhfitValidationDecision || this.isRHFitValidating;
    }

    confirmRHFitValidation() {
        if (this.rhfitCannotSubmit) return;
        this.isRHFitValidating = true;
        validateRHFitInterview({
            oppId: this.rhfitValidationOppId,
            recruiterScore: this.rhfitValidationScore,
            decision: this.rhfitValidationDecision,
            recruiterNotes: this.rhfitValidationNotes
        })
            .then(result => this.refreshDashboardData().then(() => result))
            .then(result => {
                this.showRHFitValidationModal = false;
                this.showDetailModal = false;
                let msg = 'Validation RH Fit enregistree.';
                let type = 'success';
                if (result.newStage === 'Closed Won') {
                    msg = 'Candidat embauche (Closed Won).';
                } else if (result.newStage === 'Closed Lost') {
                    msg = 'Candidat non retenu apres RH Fit.';
                    type = 'error';
                } else if (result.newStage === 'RH Fit') {
                    msg = 'Candidat maintenu en RH Fit pour revue complementaire.';
                    type = 'info';
                }
                this.showToast(msg, type);
            })
            .catch(err => {
                this.showToast('Erreur validation RH Fit : ' + (err.body ? err.body.message : err.message), 'error');
            })
            .finally(() => {
                this.isRHFitValidating = false;
            });
    }

    openValidationModal() {
        const opp = this.detailOpp;
        if (!opp.hasTechScore) {
            this.showToast('❌ Aucun résultat technique à valider.', 'error');
            return;
        }
        this.validationOppId = opp.Id;
        this.validationScore = opp.techScore;
        this.validationOriginalScore = opp.techScore;
        this.validationDecision = '';
        this.showValidationModal = true;
        this.validationDetails = null;
        this.loadingDetails = true;
        this.obsCommunication = 0;
        this.obsApproach = 0;
        this.obsAutonomy = 0;
        this.observationNotes = '';
        this.existingManagerNotes = '';

        getInterviewDetails({ oppId: opp.Id })
            .then(result => {
                this.validationDetails = result;
                if (result.managerScore) {
                    this.validationScore = Math.round(result.managerScore);
                }
                if (result.managerNotes) {
                    this.existingManagerNotes = result.managerNotes;
                }
                this.loadingDetails = false;
            })
            .catch(() => { this.loadingDetails = false; });
    }

    closeValidationModal() {
        this.showValidationModal = false;
    }

    handleValidationScoreChange(e) {
        this.validationScore = parseInt(e.target.value, 10) || 0;
    }

    setDecisionAccept() { this.validationDecision = 'accept'; }
    setDecisionReject() { this.validationDecision = 'reject'; }

    get validationCanSubmit() {
        return this.validationDecision && !this.isValidating;
    }

    get validationCannotSubmit() {
        return !this.validationDecision || this.isValidating;
    }

    get validationScoreAdjusted() {
        return this.validationScore !== this.validationOriginalScore;
    }

    get btnAcceptClass() {
        return 'btn-decision btn-accept' + (this.validationDecision === 'accept' ? ' decision-active' : '');
    }

    get btnRejectClass() {
        return 'btn-decision btn-reject' + (this.validationDecision === 'reject' ? ' decision-active' : '');
    }

    get hasValidationProblems() {
        return this.validationDetails && this.validationDetails.problemResults && this.validationDetails.problemResults.length > 0;
    }

    // Star rating getters
    _buildStars(rating) {
        return [1, 2, 3, 4, 5].map(v => ({
            key: v,
            value: v,
            cls: v <= rating ? 'obs-star obs-star-active' : 'obs-star'
        }));
    }
    get starsCommunication() { return this._buildStars(this.obsCommunication); }
    get starsApproach() { return this._buildStars(this.obsApproach); }
    get starsAutonomy() { return this._buildStars(this.obsAutonomy); }

    handleStarClick(e) {
        const criteria = e.currentTarget.dataset.criteria;
        const value = parseInt(e.currentTarget.dataset.value, 10);
        if (criteria === 'communication') this.obsCommunication = value;
        else if (criteria === 'approach') this.obsApproach = value;
        else if (criteria === 'autonomy') this.obsAutonomy = value;
    }

    handleObsNotesChange(e) {
        this.observationNotes = e.target.value;
    }

    _buildManagerNotes() {
        let notes = '';
        if (this.obsCommunication) notes += 'Communication: ' + this.obsCommunication + '/5\n';
        if (this.obsApproach) notes += 'Approche: ' + this.obsApproach + '/5\n';
        if (this.obsAutonomy) notes += 'Autonomie: ' + this.obsAutonomy + '/5\n';
        if (this.observationNotes) notes += '---\n' + this.observationNotes;
        return notes.trim();
    }

    get validationProblems() {
        if (!this.validationDetails || !this.validationDetails.problemResults) return [];
        return this.validationDetails.problemResults.map((p, i) => ({
            ...p,
            index: i + 1,
            scoreClass: p.aiScore >= 70 ? 'vp-score-high' : p.aiScore >= 50 ? 'vp-score-mid' : 'vp-score-low',
            truncatedAnswer: p.candidateAnswer ? (p.candidateAnswer.length > 200 ? p.candidateAnswer.substring(0, 200) + '…' : p.candidateAnswer) : '—'
        }));
    }

    async confirmValidation() {
        if (!this.validationDecision) return;
        this.isValidating = true;
        try {
            const result = await validateScore({
                oppId: this.validationOppId,
                managerScore: this.validationScore,
                decision: this.validationDecision,
                managerNotes: this._buildManagerNotes()
            });
            this.showValidationModal = false;
            this.showDetailModal = false;
            // Update local data
            const newStage = result.newStage;
            this.allOpps = this.allOpps.map(o => {
                if (o.Id === this.validationOppId) {
                    return this.mapOpp({ ...o, StageName: newStage, managerValidatedScore: this.validationScore });
                }
                return o;
            });
            this.applyFilter();
            const msg = result.passed
                ? '✅ Candidat validé — avancé à ' + newStage
                : '❌ Candidat non retenu — ' + newStage;
            this.showToast(msg, result.passed ? 'success' : 'error');
        } catch (err) {
            this.showToast('❌ Erreur: ' + (err.body ? err.body.message : err.message), 'error');
        } finally {
            this.isValidating = false;
        }
    }

    stopPropagationValidation(e) { e.stopPropagation(); }

    openArchValidationModal(event) {
        let id = null;
        if (event && event.currentTarget && event.currentTarget.dataset) {
            id = event.currentTarget.dataset.id;
        }
        if (!id && this.detailOpp) {
            id = this.detailOpp.Id;
        }
        if (!id) return;

        const opp = this.allOpps.find(o => o.Id === id) || this.detailOpp;
        if (!opp || !opp.archScheduled) {
            this.showToast('❌ Entretien architecture non planifie pour ce candidat.', 'error');
            return;
        }

        this.archValidationOppId = id;
        this.archValidationCandidateName = opp.Name || '';
        this.archValidationDecision = '';
        this.archValidationNotes = '';
        this.isArchValidating = false;

        const base = opp.archScore != null && opp.archScore > 0
            ? Math.max(1, Math.min(5, Math.round((opp.archScore / 100) * 5)))
            : 0;
        this.archDesignScore = base;
        this.archTradeoffScore = base;
        this.archScalabilityScore = base;
        this.archCommunicationScore = base;
        this.archCollaborationScore = base;

        this.showArchValidationModal = true;
    }

    closeArchValidationModal() {
        this.showArchValidationModal = false;
        this.isArchValidating = false;
    }

    stopPropagationArchValidation(e) {
        e.stopPropagation();
    }

    get archStarsDesign() { return this._buildStars(this.archDesignScore); }
    get archStarsTradeoff() { return this._buildStars(this.archTradeoffScore); }
    get archStarsScalability() { return this._buildStars(this.archScalabilityScore); }
    get archStarsCommunication() { return this._buildStars(this.archCommunicationScore); }
    get archStarsCollaboration() { return this._buildStars(this.archCollaborationScore); }

    handleArchStarClick(e) {
        const criteria = e.currentTarget.dataset.criteria;
        const value = parseInt(e.currentTarget.dataset.value, 10);
        if (criteria === 'design') this.archDesignScore = value;
        else if (criteria === 'tradeoff') this.archTradeoffScore = value;
        else if (criteria === 'scalability') this.archScalabilityScore = value;
        else if (criteria === 'communication') this.archCommunicationScore = value;
        else if (criteria === 'collaboration') this.archCollaborationScore = value;
    }

    onArchValidationNotesChange(e) {
        this.archValidationNotes = e.target.value;
    }

    setArchDecisionAccept() { this.archValidationDecision = 'accept'; }
    setArchDecisionReview() { this.archValidationDecision = 'review'; }
    setArchDecisionReject() { this.archValidationDecision = 'reject'; }

    get btnArchAcceptClass() {
        return 'btn-decision btn-accept' + (this.archValidationDecision === 'accept' ? ' decision-active' : '');
    }

    get btnArchReviewClass() {
        return 'btn-decision btn-review' + (this.archValidationDecision === 'review' ? ' decision-active' : '');
    }

    get btnArchRejectClass() {
        return 'btn-decision btn-reject' + (this.archValidationDecision === 'reject' ? ' decision-active' : '');
    }

    get archComputedScore() {
        const score =
            ((this.archDesignScore / 5) * 30) +
            ((this.archTradeoffScore / 5) * 25) +
            ((this.archScalabilityScore / 5) * 20) +
            ((this.archCommunicationScore / 5) * 15) +
            ((this.archCollaborationScore / 5) * 10);
        return Math.round(score * 10) / 10;
    }

    get archCriteriaCompleted() {
        return [
            this.archDesignScore,
            this.archTradeoffScore,
            this.archScalabilityScore,
            this.archCommunicationScore,
            this.archCollaborationScore
        ].every(v => v > 0);
    }

    get archCannotSubmit() {
        return !this.archValidationDecision || !this.archCriteriaCompleted || this.isArchValidating;
    }

    async confirmArchValidation() {
        if (this.archCannotSubmit) return;
        this.isArchValidating = true;
        try {
            const result = await validateArchitectureInterview({
                oppId: this.archValidationOppId,
                designScore: this.archDesignScore,
                tradeoffScore: this.archTradeoffScore,
                scalabilityScore: this.archScalabilityScore,
                communicationScore: this.archCommunicationScore,
                collaborationScore: this.archCollaborationScore,
                decision: this.archValidationDecision,
                managerNotes: this.archValidationNotes
            });

            const newStage = result.newStage;
            const nextArchStatus = newStage === 'Architecture' ? 'Review' : 'Completed';
            const validatedScore = result.finalScore != null
                ? Math.round(result.finalScore * 10) / 10
                : this.archComputedScore;

            this.allOpps = this.allOpps.map(o => {
                if (o.Id === this.archValidationOppId) {
                    return this.mapOpp({
                        ...o,
                        StageName: newStage,
                        archScore: validatedScore,
                        archStatus: nextArchStatus
                    });
                }
                return o;
            });
            this.applyFilter();

            const refreshed = this.allOpps.find(o => o.Id === this.archValidationOppId);
            if (refreshed) this.detailOpp = refreshed;

            this.showArchValidationModal = false;
            this.showDetailModal = false;

            let msg = '✅ Validation architecture enregistree.';
            let toastType = 'success';
            if (newStage === 'RH Fit') {
                msg = '✅ Candidat valide: passage a RH Fit + invitation envoyee.';
            } else if (newStage === 'Closed Lost') {
                msg = '❌ Candidat refuse apres architecture.';
                toastType = 'error';
            } else if (newStage === 'Architecture') {
                msg = 'ℹ️ Candidat conserve en Architecture pour revue complementaire.';
                toastType = 'info';
            }
            this.showToast(msg, toastType);
        } catch (err) {
            this.showToast('❌ Erreur: ' + (err.body ? err.body.message : err.message), 'error');
        } finally {
            this.isArchValidating = false;
        }
    }

    // ══════════════════════════════════════
    // IA RE-SCORING
    // ══════════════════════════════════════

    handleRescore(event) {
        const id = event.currentTarget.dataset.id;
        this.showToast('Analyse IA en cours...', 'success');
        rescoreCandidat({ oppId: id })
            .then(result => {
                this.allOpps = this.allOpps.map(o => {
                    if (o.Id === id) {
                        return this.mapOpp({
                            ...o,
                            score: result.score,
                            aiReco: result.recommendation,
                            aiForts: result.pointsForts
                        });
                    }
                    return o;
                });
                this.applyFilter();
                this.showToast('Score IA mis à jour : ' + Math.round(result.score) + '%', 'success');
            })
            .catch(err => {
                this.showToast('Erreur IA : ' + (err.body ? err.body.message : err.message), 'error');
            });
    }
}
