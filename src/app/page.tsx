import CalibrationDemo from "@/ui/CalibrationDemo";

export default function Home() {
  return (
    <main className="mx-auto max-w-2xl px-6 py-16">
      <h1 className="text-3xl font-semibold text-ink">plumb</h1>
      <p className="mt-3 text-secondary">
        Predict how you&apos;ll do, see the truth, and find out how well your
        confidence matched your results.
      </p>

      <div className="mt-8">
        <CalibrationDemo />
      </div>
    </main>
  );
}
