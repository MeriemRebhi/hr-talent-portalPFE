import { LightningElement, track, wire } from 'lwc';
import getRecruteurData   from '@salesforce/apex/InternalDashboardController.getRecruteurData';
import updateOpportunityStage from '@salesforce/apex/InternalDashboardController.updateOpportunityStage';
import scheduleGamingTest from '@salesforce/apex/InternalDashboardController.scheduleGamingTest';
import scheduleBatchGamingTests from '@salesforce/apex/InternalDashboardController.scheduleBatchGamingTests';
import cancelGamingTest from '@salesforce/apex/InternalDashboardController.cancelGamingTest';
import scheduleTechnicalInterview from '@salesforce/apex/InternalDashboardController.scheduleTechnicalInterview';
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

    get planOppShortId() {
        return this.planOppId ? this.planOppId.substring(0, 15) : '';
    }

    @wire(getRecruteurData)
    wiredData({ data, error }) {
        if (data) {
            this.totalCandidats = data.totalCandidats || 0;
            this.enGaming       = data.enGaming       || 0;
            this.enTechnique    = data.enTechnique    || 0;
            this.enArchitecture = data.enArchitecture || 0;
            this.enRHFit        = data.enRHFit        || 0;
            this.closedCount    = data.closed         || 0;

            this.allOpps = (data.rows || []).map(o => this.mapOpp(o));
            this.applyFilter();
            this.isLoaded = true;
        } else if (error) {
            this.isLoaded = true;
        }
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
            techRescheduleRequested: !!o.techRescheduleRequested
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

    // ── Batch planning ──
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
