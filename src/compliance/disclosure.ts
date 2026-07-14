/**
 * Onboarding disclosures. Plain, caring, task-neutral copy shown at sign-up so the
 * one exception to "everything you write is private" (the crisis path, P16) is
 * DISCLOSED up front — never a surprise. This lives outside src/safety (it names
 * no escalation data), so the safety module stays isolated to its capture boundary.
 */

export const CRISIS_DISCLOSURE =
  "Almost everything you write here is private. The one exception: if you ever " +
  "write something that sounds like you might be in danger of hurting yourself, a " +
  "caring adult at your school will be told, so you can get help.";

/**
 * The wellbeing disclosure. Surfacing "something outside school is making school
 * harder" to a teacher is a SECOND, softer exception to the privacy promise, so it
 * is disclosed up front too — never a surprise. Kept gentle and specific so a
 * student knows exactly what a teacher might see, and why (to help, not to judge).
 */
export const WELLBEING_DISCLOSURE =
  "One more thing: if you mention that something outside school — like things at " +
  "home, a job, or not getting enough sleep — is making school harder, your teacher " +
  "may see that, so they can check in and help.";
