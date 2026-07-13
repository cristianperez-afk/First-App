import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';
import { initializeApp } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as logger from 'firebase-functions/logger';

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

type ReminderState = 'completed' | 'dueToday' | 'upcoming' | 'overdue' | 'scheduled';

interface ScheduleItem {
  vaccineName?: string;
  scheduledDate?: string;
  notes?: string;
  location?: string;
  status?: string;
  doseIntervalDays?: number;
  reminderLeadDays?: number;
  lastReminderState?: ReminderState;
  lastReminderDate?: string;
  completedAt?: string | Date | Timestamp;
}

interface PatientData {
  vaccinationSchedules?: ScheduleItem[];
  nextVaccine?: string;
  nextDue?: string;
  nextDoseIntervalDays?: number;
  nextFollowUpDue?: string;
  childName?: string;
  email?: string;
}

function parseDate(value: unknown): Date | null {
  if (!value) {
    return null;
  }

  if (value instanceof Timestamp) {
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

function sameDay(first: Date, second: Date): boolean {
  return (
    first.getFullYear() === second.getFullYear() &&
    first.getMonth() === second.getMonth() &&
    first.getDate() === second.getDate()
  );
}

function formatDate(date: Date): string {
  return [
    date.getFullYear().toString().padStart(4, '0'),
    (date.getMonth() + 1).toString().padStart(2, '0'),
    date.getDate().toString().padStart(2, '0'),
  ].join('-');
}

function addDays(date: Date, days: number): Date {
  const copy = new Date(date);
  copy.setDate(copy.getDate() + days);
  return copy;
}

function isCompletedStatus(value: unknown): boolean {
  return typeof value === 'string' && value.toLowerCase() === 'completed';
}

function formatOptionalDate(date: Date | null): string | null {
  return date ? formatDate(date) : null;
}

function computeNextDoseFields(
  patient: PatientData,
  schedule: ScheduleItem,
  completedAt: Date,
): {
  nextVaccine: string;
  nextDue: string | null;
  nextDoseIntervalDays: number;
  nextFollowUpDue: string | null;
} {
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

function findCompletedTransition(
  beforeSchedules: ScheduleItem[],
  afterSchedules: ScheduleItem[],
): { schedule: ScheduleItem; completedAt: Date } | null {
  const fallbackCompletedAt = new Date();
  let chosen: { schedule: ScheduleItem; completedAt: Date } | null = null;

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

function resolveDueDate(schedule: ScheduleItem): Date | null {
  const scheduledDate = parseDate(schedule.scheduledDate);
  if (!scheduledDate) {
    return null;
  }

  if ((schedule.status ?? '').toLowerCase() === 'completed' && (schedule.doseIntervalDays ?? 0) > 0) {
    return addDays(scheduledDate, schedule.doseIntervalDays ?? 0);
  }

  return scheduledDate;
}

function classifyReminder(
  schedule: ScheduleItem,
  reminderLeadDays: number,
  now: Date,
): { state: ReminderState; dueDate: Date | null } {
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

function shouldNotify(schedule: ScheduleItem, state: ReminderState, todayKey: string): boolean {
  if (state === 'completed' || state === 'scheduled') {
    return false;
  }

  if (schedule.lastReminderState !== state) {
    return true;
  }

  return schedule.lastReminderDate !== todayKey;
}

function buildNotification(
  childName: string,
  schedule: ScheduleItem,
  dueDate: Date | null,
  state: ReminderState,
): { title: string; body: string } {
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

async function notifyParentForPatient(patientDoc: FirebaseFirestore.QueryDocumentSnapshot): Promise<void> {
  const patient = patientDoc.data();
  const parentEmail = patient.email as string | undefined;

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

  const tokens = new Set<string>();
  const primaryToken = user.fcmToken as string | undefined;
  if (primaryToken) {
    tokens.add(primaryToken);
  }

  const additionalTokens = user.fcmTokens as string[] | undefined;
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
  const notifications: Array<{ title: string; body: string }> = [];
  let needsWriteback = false;

  for (let index = 0; index < schedules.length; index += 1) {
    const schedule = schedules[index] as ScheduleItem;
    const { state, dueDate } = classifyReminder(schedule, reminderLeadDays, new Date());

    if (!shouldNotify(schedule, state, todayKey)) {
      continue;
    }

    notifications.push(
      buildNotification(patient.childName ?? 'Patient', schedule, dueDate, state),
    );

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
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
}

export const syncNextVaccinationOnCompletion = onDocumentUpdated('patients/{patientId}', async (event) => {
  const change = event.data;
  if (!change) {
    return;
  }

  const before = change.before.data() as PatientData | undefined;
  const after = change.after.data() as PatientData | undefined;

  if (!before || !after) {
    return;
  }

  const transition = findCompletedTransition(
    Array.isArray(before.vaccinationSchedules) ? before.vaccinationSchedules : [],
    Array.isArray(after.vaccinationSchedules) ? after.vaccinationSchedules : [],
  );

  if (!transition) {
    return;
  }

  const nextDoseFields = computeNextDoseFields(after, transition.schedule, transition.completedAt);

  await change.after.ref.update({
    ...nextDoseFields,
    updatedAt: FieldValue.serverTimestamp(),
  });
});

export const dailyVaccinationReminderSweep = onSchedule('every day 08:00', async () => {
  const patientsSnapshot = await db.collection('patients').get();

  for (const patientDoc of patientsSnapshot.docs) {
    try {
      await notifyParentForPatient(patientDoc);
    } catch (error) {
      logger.error('Failed to process vaccination reminders', {
        patientId: patientDoc.id,
        error,
      });
    }
  }
});