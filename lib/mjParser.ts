export interface ParsedMJResponse {
  narration: string;
  movementAccepted: boolean | null;
  movementReason?: string;
  hpChanges: Array<{ figurineName: string; delta: number }>;
  inventoryChanges: Array<{ figurineName: string; item: string }>;
}

export function parseMJResponse(raw: string): ParsedMJResponse {
  let narration = raw.trim();
  let movementAccepted: boolean | null = null;
  let movementReason: string | undefined;

  const movementMatch = narration.match(
    /\[DEPLACEMENT:\s*(ACCEPTE|REFUSE(?:\s*-\s*(.+))?)\]/i,
  );
  if (movementMatch) {
    movementAccepted = movementMatch[1].toUpperCase().startsWith('ACCEPTE');
    movementReason = movementMatch[2]?.trim();
    narration = narration.replace(movementMatch[0], '').trim();
  }

  const hpChanges: ParsedMJResponse['hpChanges'] = [];
  const hpRegex = /\[PV:\s*([^-\]]+?)\s*(-?\d+)\]/gi;
  let hpMatch: RegExpExecArray | null;
  while ((hpMatch = hpRegex.exec(raw)) !== null) {
    hpChanges.push({
      figurineName: hpMatch[1].trim(),
      delta: Number(hpMatch[2]),
    });
    narration = narration.replace(hpMatch[0], '').trim();
  }

  const inventoryChanges: ParsedMJResponse['inventoryChanges'] = [];
  const invRegex = /\[INVENTAIRE:\s*([^+\]]+?)\s*\+([^\]]+)\]/gi;
  let invMatch: RegExpExecArray | null;
  while ((invMatch = invRegex.exec(raw)) !== null) {
    inventoryChanges.push({
      figurineName: invMatch[1].trim(),
      item: invMatch[2].trim(),
    });
    narration = narration.replace(invMatch[0], '').trim();
  }

  return {
    narration: narration.trim(),
    movementAccepted,
    movementReason,
    hpChanges,
    inventoryChanges,
  };
}
