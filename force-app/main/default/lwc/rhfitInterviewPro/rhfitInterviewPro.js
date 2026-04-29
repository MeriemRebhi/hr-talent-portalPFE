import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';

import getRHFitInterviewInfo from '@salesforce/apex/RHFitInterviewController.getRHFitInterviewInfo';
import requestReschedule from '@salesforce/apex/RHFitInterviewController.requestReschedule';

const STEP_LOADING = 'loading';
const STEP_ERROR = 'error';
const STEP_WELCOME = 'welcome';
const STEP_JOIN = 'join';
const STEP_DONE = 'done';

export default class RhfitInterviewPro extends LightningElement {
    @track step = STEP_LOADING;
    @track errorMessage = '';

    oppId;
    candidateName = '';
    jobTitle = '';
    meetLink = '';
    jitsiRoom = '';
    scheduledDate = null;
    duration = '';
    status = '';
    rescheduleRequested = false;

    showRescheduleModal = false;
    rescheduleReason = '';
    isRescheduling = false;

    @track noticeMessage = '';
    @track noticeVariant = 'info';

    @wire(CurrentPageReference)
    setPageRef(ref) {
        if (ref && ref.state && ref.state.id) {
            this.oppId = ref.state.id;
        }
    }

    connectedCallback() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => this.loadInterview(), 250);
    }

    get isStepLoading() { return this.step === STEP_LOADING; }
    get isStepError() { return this.step === STEP_ERROR; }
    get isStepWelcome() { return this.step === STEP_WELCOME; }
    get isStepJoin() { return this.step === STEP_JOIN; }
    get isStepDone() { return this.step === STEP_DONE; }

    get jitsiUrl() {
        if (this.jitsiRoom) return `https://meet.jit.si/${this.jitsiRoom}`;
        return this.meetLink || '';
    }

    get scheduledDateFormatted() {
        if (!this.scheduledDate) return '';
        try {
            const d = new Date(this.scheduledDate);
            const pad = (n) => String(n).padStart(2, '0');
            return `${pad(d.getDate())}/${pad(d.getMonth() + 1)}/${d.getFullYear()} a ${pad(d.getHours())}:${pad(d.getMinutes())}`;
        } catch (e) {
            return '';
        }
    }

    get durationLabel() {
        const map = {
            '30': '30 minutes',
            '45': '45 minutes',
            '60': '1 heure',
            '90': '1h30'
        };
        return map[this.duration] || (this.duration ? `${this.duration} min` : 'N/A');
    }

    get statusLabel() {
        return this.status || 'Scheduled';
    }

    get statusClass() {
        const s = (this.status || '').toLowerCase();
        if (s.includes('completed') || s.includes('validated')) return 'status-badge s-completed';
        if (s.includes('review')) return 'status-badge s-processing';
        if (s.includes('error')) return 'status-badge s-error';
        return 'status-badge s-draft';
    }

    get canReschedule() {
        return !!this.scheduledDate && !this.rescheduleRequested;
    }

    get rescheduleButtonLabel() {
        return this.isRescheduling ? 'Envoi...' : 'Confirmer le report';
    }

    get showNotice() {
        return !!this.noticeMessage;
    }

    get noticeClass() {
        return `notice notice-${this.noticeVariant}`;
    }

    showBanner(message, variant = 'info') {
        this.noticeMessage = message;
        this.noticeVariant = variant;
    }

    async loadInterview() {
        try {
            if (!this.oppId) {
                const url = new URL(window.location.href);
                this.oppId = url.searchParams.get('id');
            }
            if (!this.oppId) {
                this.errorMessage = 'Identifiant de candidature manquant dans l URL.';
                this.step = STEP_ERROR;
                return;
            }

            const info = await getRHFitInterviewInfo({ oppId: this.oppId });
            this.candidateName = info.candidateName || '';
            this.jobTitle = info.jobTitle || '';
            this.meetLink = info.meetLink || '';
            this.jitsiRoom = info.jitsiRoom || '';
            this.scheduledDate = info.scheduledDate || null;
            this.duration = info.duration != null ? String(info.duration) : '';
            this.status = info.status || '';
            this.rescheduleRequested = !!info.rescheduleRequested;

            if (info.alreadyCompleted) {
                this.step = STEP_DONE;
                return;
            }
            if (!info.isScheduled) {
                this.errorMessage = 'Aucun entretien RH Fit programme pour cette candidature.';
                this.step = STEP_ERROR;
                return;
            }
            this.step = STEP_WELCOME;
        } catch (error) {
            this.errorMessage = this.getErrorMessage(error);
            this.step = STEP_ERROR;
        }
    }

    handleJoinFlow() {
        this.step = STEP_JOIN;
        this.showBanner('Rejoignez la visio. Le recruteur anime les questions RH Fit.', 'info');
    }

    handleBackToWelcome() {
        this.step = STEP_WELCOME;
    }

    handleMarkDone() {
        this.step = STEP_DONE;
    }

    handleShowReschedule() {
        this.showRescheduleModal = true;
    }

    handleCloseReschedule() {
        this.showRescheduleModal = false;
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    handleRescheduleReasonChange(event) {
        this.rescheduleReason = event.target.value;
    }

    async handleSubmitReschedule() {
        this.isRescheduling = true;
        try {
            await requestReschedule({
                oppId: this.oppId,
                reason: this.rescheduleReason
            });
            this.rescheduleRequested = true;
            this.showRescheduleModal = false;
            this.showBanner('Demande de report envoyee au recruteur.', 'success');
        } catch (error) {
            this.showBanner(this.getErrorMessage(error), 'error');
        }
        this.isRescheduling = false;
    }

    getErrorMessage(error) {
        if (!error) return 'Erreur inattendue.';
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return 'Erreur inattendue.';
    }
}
