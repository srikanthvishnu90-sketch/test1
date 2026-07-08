import Link from "next/link";

// Placeholder slots — wire these to the school's real tutoring/booking service.
const SLOTS = [
  "Mon · 3:30 PM",
  "Tue · 4:00 PM",
  "Wed · 3:30 PM",
  "Thu · 4:15 PM",
];

export default function Tutoring() {
  return (
    <main className="mx-auto max-w-2xl px-6 py-16">
      <Link
        href="/"
        className="text-sm text-secondary transition-colors hover:text-ink"
      >
        ← Back
      </Link>

      <h1 className="mt-4 text-3xl font-semibold text-ink">
        Book time with a tutor
      </h1>
      <p className="mt-3 text-secondary">
        Grab a slot for help outside class — bring the questions you flagged and
        what you said you&apos;d want to go over.
      </p>

      <div className="mt-8 rounded-card border border-ink-wash bg-white p-6">
        <p className="text-sm font-semibold text-ink">This week</p>
        <ul className="mt-3 grid gap-2 sm:grid-cols-2">
          {SLOTS.map((slot) => (
            <li key={slot}>
              <button
                type="button"
                className="w-full rounded-control border border-ink-wash px-4 py-3 text-left text-sm text-ink-black transition-colors hover:bg-ink-wash"
              >
                {slot}
              </button>
            </li>
          ))}
        </ul>
        <p className="mt-4 text-xs text-secondary">
          Placeholder — connect your school&apos;s tutoring or booking service
          here.
        </p>
      </div>
    </main>
  );
}
