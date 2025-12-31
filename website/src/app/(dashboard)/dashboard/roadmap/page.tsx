"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

export default function RoadmapPage() {
  return (
    <div className="flex flex-1 flex-col gap-4 p-4 pt-0">
      <div>
        <h2 className="text-3xl font-bold tracking-tight">Roadmap</h2>
        <p className="text-muted-foreground">
          Short-term focus items for V1 readiness.
        </p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Next focus</CardTitle>
        </CardHeader>
        <CardContent className="space-y-6">
          <div className="space-y-2">
            <div className="flex items-center gap-2">
              <Badge>1</Badge>
              <div className="font-medium">Display pairing + device management</div>
            </div>
            <ul className="list-disc pl-6 text-sm text-muted-foreground space-y-1">
              <li>Get the DisplayApp running (menu/campaign rendering shell).</li>
              <li>Pair device to a Display using provisioning token / pairing flow.</li>
              <li>Heartbeat / last-seen updates and reliable online/offline status.</li>
              <li>Assign what a display shows (menu vs campaign) and scheduling.</li>
            </ul>
          </div>

          <div className="space-y-2">
            <div className="flex items-center gap-2">
              <Badge>2</Badge>
              <div className="font-medium">Role guardrails</div>
            </div>
            <ul className="list-disc pl-6 text-sm text-muted-foreground space-y-1">
              <li>Prevent self-demotion and prevent removing the last Owner.</li>
              <li>Hide role UI for non-Owners; add clearer error messages.</li>
              <li>Keep confirmations for sensitive actions (email + roles).</li>
            </ul>
          </div>

          <div className="space-y-2">
            <div className="flex items-center gap-2">
              <Badge>3</Badge>
              <div className="font-medium">Menu polish</div>
            </div>
            <ul className="list-disc pl-6 text-sm text-muted-foreground space-y-1">
              <li>Template styling: colours, backgrounds, typography.</li>
              <li>Per-section/per-item visuals and better layout controls.</li>
              <li>Finish POS fields usability (SKU/image) where needed.</li>
            </ul>
          </div>

          <div className="text-sm text-muted-foreground">
            Note: pairing + DisplayApp likely need to evolve together.
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
