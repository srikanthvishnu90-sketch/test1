import { NextResponse } from "next/server";
import { getCycleRepository } from "@/composition.server";
import { recordCycle, type RecordCycleInput } from "@/application/recordCycle";

// pg needs the Node.js runtime, and the store is stateful → never cache.
export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** GET /api/cycles → all persisted cycles (oldest first). */
export async function GET(): Promise<Response> {
  const cycles = await getCycleRepository().list();
  return NextResponse.json({ cycles });
}

/**
 * POST /api/cycles → record a cycle from raw inputs. Body shape: RecordCycleInput
 * ({ items: [{ itemId, confidence, correct }], predictedScore, reflection? }).
 * Domain invariants are enforced by recordCycle; violations return 400.
 */
export async function POST(req: Request): Promise<Response> {
  let input: RecordCycleInput;
  try {
    input = (await req.json()) as RecordCycleInput;
  } catch {
    return NextResponse.json({ error: "Invalid JSON body." }, { status: 400 });
  }

  try {
    const cycle = await recordCycle(getCycleRepository(), input);
    return NextResponse.json({ cycle }, { status: 201 });
  } catch (e) {
    return NextResponse.json(
      { error: e instanceof Error ? e.message : "Bad request." },
      { status: 400 },
    );
  }
}
