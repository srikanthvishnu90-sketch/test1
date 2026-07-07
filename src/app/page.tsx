export default function Home() {
  return (
    <main className="mx-auto max-w-2xl px-6 py-16">
      <h1 className="text-3xl font-semibold text-ink">plumb</h1>
      <p className="mt-3 text-secondary">
        A personal instrument for accurate academic self-knowledge.
      </p>
      <div className="mt-8 rounded-card bg-white p-6">
        <p className="text-sm text-secondary">
          Scaffold only — ports &amp; adapters folders are in place under{" "}
          <code>src/</code>, with in-memory adapters and no keys. Read{" "}
          <code>CLAUDE.md</code> for the project context and guardrails before
          adding domain logic.
        </p>
      </div>
    </main>
  );
}
