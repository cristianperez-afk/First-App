"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.dailyVaccinationReminderSweep = exports.syncNextVaccinationOnCompletion = void 0;
const firestore_1 = require("firebase-admin/firestore");
const app_1 = require("firebase-admin/app");
const messaging_1 = require("firebase-admin/messaging");
const firestore_2 = require("firebase-functions/v2/firestore");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const logger = __importStar(require("firebase-functions/logger"));
(0, app_1.initializeApp)();
const db = (0, firestore_1.getFirestore)();
const messaging = (0, messaging_1.getMessaging)();
function parseDate(value) {
    if (!value) {
        return null;
    }
    if (value instanceof firestore_1.Timestamp) {
        return value.toDate();
    }
    if (value instanceof Date) {
        return value;
    }
    if (typeof value === 'string') {
        const parsed = new Date(value);
        if (!Number.isNaN(parsed.getTime())) {
            return parsed;
        }
    }
    return null;
}
function sameDay(first, second) {
    return (first.getFullYear() === second.getFullYear() &&
        first.getMonth() === second.getMonth() &&
        first.getDate() === second.getDate());
}
function formatDate(date) {
    return [
        date.getFullYear().toString().padStart(4, '0'),
        (date.getMonth() + 1).toString().padStart(2, '0'),
        date.getDate().toString().padStart(2, '0'),
    ].join('-');
}
function addDays(date, days) {
    const copy = new Date(date);
    copy.setDate(copy.getDate() + days);
    return copy;
}
function isCompletedStatus(value) {
    return typeof value === 'string' && value.toLowerCase() === 'completed';
}
function formatOptionalDate(date) {
    return date ? formatDate(date) : null;
}
function computeNextDoseFields(patient, schedule, completedAt) {
    const rawInterval = Number(schedule.doseIntervalDays ?? patient.nextDoseIntervalDays ?? 0);
    const nextDoseIntervalDays = Number.isFinite(rawInterval) ? rawInterval : 0;
    const nextVaccine = schedule.vaccineName ?? patient.nextVaccine ?? 'Vaccination';
    const nextDueDate = nextDoseIntervalDays > 0 ? addDays(completedAt, nextDoseIntervalDays) : completedAt;
    const nextFollowUpDate = nextDoseIntervalDays > 0 ? addDays(nextDueDate, nextDoseIntervalDays) : null;
    return {
        nextVaccine,
        nextDue: formatOptionalDate(nextDueDate),
        nextDoseIntervalDays,
        nextFollowUpDue: formatOptionalDate(nextFollowUpDate),
    };
}
function findCompletedTransition(beforeSchedules, afterSchedules) {
    const fallbackCompletedAt = new Date();
    let chosen = null;
    for (let index = 0; index < Math.max(beforeSchedules.length, afterSchedules.length); index += 1) {
        const previous = beforeSchedules[index];
        const current = afterSchedules[index];
        if (!current || !isCompletedStatus(current.status) || isCompletedStatus(previous?.status)) {
            continue;
        }
        const completedAt = parseDate(current.completedAt) ?? fallbackCompletedAt;
        if (!chosen || completedAt > chosen.completedAt) {
            chosen = { schedule: current, completedAt };
        }
    }
    return chosen;
}
function resolveDueDate(schedule) {
    const scheduledDate = parseDate(schedule.scheduledDate);
    if (!scheduledDate) {
        return null;
    }
    if ((schedule.status ?? '').toLowerCase() === 'completed' && (schedule.doseIntervalDays ?? 0) > 0) {
        return addDays(scheduledDate, schedule.doseIntervalDays ?? 0);
    }
    return scheduledDate;
}
function classifyReminder(schedule, reminderLeadDays, now) {
    const dueDate = resolveDueDate(schedule);
    const storedStatus = (schedule.status ?? '').toLowerCase();
    if (storedStatus === 'completed') {
        return { state: 'completed', dueDate };
    }
    if (!dueDate) {
        return { state: 'scheduled', dueDate };
    }
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const target = new Date(dueDate.getFullYear(), dueDate.getMonth(), dueDate.getDate());
    const reminderStart = addDays(target, reminderLeadDays * -1);
    if (today > target) {
        return { state: 'overdue', dueDate };
    }
    if (sameDay(today, target)) {
        return { state: 'dueToday', dueDate };
    }
    if (today >= reminderStart) {
        return { state: 'upcoming', dueDate };
    }
    return { state: 'scheduled', dueDate };
}
function shouldNotify(schedule, state, todayKey) {
    if (state === 'completed' || state === 'scheduled') {
        return false;
    }
    if (schedule.lastReminderState !== state) {
        return true;
    }
    return schedule.lastReminderDate !== todayKey;
}
function buildNotification(childName, schedule, dueDate, state) {
    const vaccineName = schedule.vaccineName ?? 'vaccination';
    const location = schedule.location ?? 'Clinic';
    const dueText = dueDate ? formatDate(dueDate) : 'TBD';
    switch (state) {
        case 'dueToday':
            return {
                title: 'Vaccination due today',
                body: `${childName} is due for ${vaccineName} today at ${location}.`,
            };
        case 'overdue':
            return {
                title: 'Vaccination overdue',
                body: `${childName} still needs ${vaccineName}. Due date was ${dueText} at ${location}.`,
            };
        case 'upcoming':
            return {
                title: 'Upcoming vaccination reminder',
                body: `${childName} has ${vaccineName} coming up on ${dueText} at ${location}.`,
            };
        case 'completed':
        case 'scheduled':
        default:
            return {
                title: 'Vaccination update',
                body: `${childName} has a scheduled vaccination update for ${vaccineName}.`,
            };
    }
}
async function notifyParentForPatient(patientDoc) {
    const patient = patientDoc.data();
    const parentEmail = patient.email;
    if (!parentEmail) {
        return;
    }
    const userDoc = await db.collection('users').doc(parentEmail).get();
    if (!userDoc.exists) {
        return;
    }
    const user = userDoc.data() ?? {};
    if (user.vaccinationReminders === false || user.pushNotificationsEnabled === false) {
        return;
    }
    const tokens = new Set();
    const primaryToken = user.fcmToken;
    if (primaryToken) {
        tokens.add(primaryToken);
    }
    const additionalTokens = user.fcmTokens;
    if (Array.isArray(additionalTokens)) {
        additionalTokens.forEach((token) => {
            if (token) {
                tokens.add(token);
            }
        });
    }
    if (tokens.size === 0) {
        return;
    }
    const reminderLeadDays = Number(user.reminderDays ?? 3);
    const schedules = Array.isArray(patient.vaccinationSchedules) ? [...patient.vaccinationSchedules] : [];
    const todayKey = formatDate(new Date());
    const notifications = [];
    let needsWriteback = false;
    for (let index = 0; index < schedules.length; index += 1) {
        const schedule = schedules[index];
        const { state, dueDate } = classifyReminder(schedule, reminderLeadDays, new Date());
        if (!shouldNotify(schedule, state, todayKey)) {
            continue;
        }
        notifications.push(buildNotification(patient.childName ?? 'Patient', schedule, dueDate, state));
        schedules[index] = {
            ...schedule,
            lastReminderState: state,
            lastReminderDate: todayKey,
            derivedReminderStatus: state,
            reminderCheckedAt: new Date().toISOString(),
        };
        needsWriteback = true;
    }
    if (notifications.length === 0) {
        return;
    }
    const tokenList = [...tokens];
    for (const notification of notifications) {
        await messaging.sendEachForMulticast({
            tokens: tokenList,
            notification,
            data: {
                patientId: patientDoc.id,
                childName: patient.childName ?? '',
                reminderState: notification.title,
            },
        });
    }
    if (needsWriteback) {
        await patientDoc.ref.update({
            vaccinationSchedules: schedules,
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        });
    }
}
exports.syncNextVaccinationOnCompletion = (0, firestore_2.onDocumentUpdated)('patients/{patientId}', async (event) => {
    const change = event.data;
    if (!change) {
        return;
    }
    const before = change.before.data();
    const after = change.after.data();
    if (!before || !after) {
        return;
    }
    const transition = findCompletedTransition(Array.isArray(before.vaccinationSchedules) ? before.vaccinationSchedules : [], Array.isArray(after.vaccinationSchedules) ? after.vaccinationSchedules : []);
    if (!transition) {
        return;
    }
    const nextDoseFields = computeNextDoseFields(after, transition.schedule, transition.completedAt);
    await change.after.ref.update({
        ...nextDoseFields,
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    });
});
exports.dailyVaccinationReminderSweep = (0, scheduler_1.onSchedule)('every day 08:00', async () => {
    const patientsSnapshot = await db.collection('patients').get();
    for (const patientDoc of patientsSnapshot.docs) {
        try {
            await notifyParentForPatient(patientDoc);
        }
        catch (error) {
            logger.error('Failed to process vaccination reminders', {
                patientId: patientDoc.id,
                error,
            });
        }
    }
});
