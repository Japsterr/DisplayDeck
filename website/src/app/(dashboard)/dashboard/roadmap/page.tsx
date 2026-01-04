"use client";

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { CheckCircle2, Circle, Clock, Rocket, Sparkles, Wrench } from "lucide-react";

const phases = [
  {
    title: "Phase 1: Core Platform",
    status: "completed",
    description: "Foundation for digital signage management",
    items: [
      { text: "Display pairing + device management", done: true },
      { text: "Campaign creation and media upload", done: true },
      { text: "Menu builder with sections and items", done: true },
      { text: "Heartbeat and online/offline status", done: true },
      { text: "User management and roles", done: true },
    ],
  },
  {
    title: "Phase 2: Templates & Info Boards",
    status: "completed",
    description: "Enhanced content options",
    items: [
      { text: "Menu templates (QSR, Drive-Thru, etc.)", done: true },
      { text: "Info Boards for directories and notices", done: true },
      { text: "Drag-and-drop menu editor", done: true },
      { text: "Display preview functionality", done: true },
      { text: "Android player app", done: true },
    ],
  },
  {
    title: "Phase 3: Analytics & Polish",
    status: "in-progress",
    description: "Insights and user experience improvements",
    items: [
      { text: "Proof-of-play analytics and reporting", done: true },
      { text: "Dashboard polish with stats cards", done: true },
      { text: "Theme toggle (dark/light mode)", done: true },
      { text: "Scheduling for campaigns", done: false },
      { text: "Multi-location support", done: false },
    ],
  },
  {
    title: "Phase 4: Enterprise Features",
    status: "planned",
    description: "Scale and advanced capabilities",
    items: [
      { text: "API keys and webhooks", done: false },
      { text: "White-label support", done: false },
      { text: "Multi-tenant management", done: false },
      { text: "Advanced scheduling rules", done: false },
      { text: "Content approval workflows", done: false },
    ],
  },
];

function StatusBadge({ status }: { status: string }) {
  switch (status) {
    case "completed":
      return (
        <Badge className="bg-green-500/10 text-green-500 hover:bg-green-500/20">
          <CheckCircle2 className="mr-1 h-3 w-3" /> Completed
        </Badge>
      );
    case "in-progress":
      return (
        <Badge className="bg-blue-500/10 text-blue-500 hover:bg-blue-500/20">
          <Clock className="mr-1 h-3 w-3" /> In Progress
        </Badge>
      );
    default:
      return (
        <Badge variant="outline">
          <Circle className="mr-1 h-3 w-3" /> Planned
        </Badge>
      );
  }
}

export default function RoadmapPage() {
  return (
    <div className="flex flex-1 flex-col gap-6 p-4 pt-0">
      <div className="flex items-start justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Roadmap</h2>
          <p className="text-muted-foreground">
            Track our progress and see what&apos;s coming next.
          </p>
        </div>
        <Badge variant="outline" className="text-xs">
          <Rocket className="mr-1 h-3 w-3" /> v0.2.3
        </Badge>
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        {phases.map((phase, index) => (
          <Card key={index} className={phase.status === "in-progress" ? "border-primary/50" : ""}>
            <CardHeader className="pb-3">
              <div className="flex items-center justify-between">
                <CardTitle className="text-lg">{phase.title}</CardTitle>
                <StatusBadge status={phase.status} />
              </div>
              <CardDescription>{phase.description}</CardDescription>
            </CardHeader>
            <CardContent>
              <ul className="space-y-2">
                {phase.items.map((item, i) => (
                  <li key={i} className="flex items-center gap-2 text-sm">
                    {item.done ? (
                      <CheckCircle2 className="h-4 w-4 text-green-500 shrink-0" />
                    ) : (
                      <Circle className="h-4 w-4 text-muted-foreground shrink-0" />
                    )}
                    <span className={item.done ? "" : "text-muted-foreground"}>
                      {item.text}
                    </span>
                  </li>
                ))}
              </ul>
            </CardContent>
          </Card>
        ))}
      </div>

      <Card className="bg-gradient-to-r from-primary/10 via-transparent to-transparent">
        <CardHeader>
          <div className="flex items-center gap-2">
            <Sparkles className="h-5 w-5 text-primary" />
            <CardTitle>Got a feature request?</CardTitle>
          </div>
          <CardDescription>
            We&apos;re always looking to improve DisplayDeck. Let us know what features would help your business.
          </CardDescription>
        </CardHeader>
      </Card>
    </div>
  );
}
