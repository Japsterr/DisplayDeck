import { Navbar } from "@/components/landing/Navbar";
import { Footer } from "@/components/landing/Footer";
import { BentoGrid, BentoGridItem } from "@/components/landing/BentoGrid";
import { LayoutDashboard, Clock, ShieldCheck, Monitor, Image as ImageIcon, Sparkles, ListChecks } from "lucide-react";

export default function FeaturesPage() {
  return (
    <div className="flex min-h-screen flex-col bg-background">
      <Navbar />
      <main className="flex-1 pt-24 pb-16">
        <div className="container px-4 md:px-6">
          <div className="flex flex-col items-center justify-center space-y-4 text-center mb-16">
            <h1 className="text-4xl font-bold tracking-tighter sm:text-6xl bg-clip-text text-transparent bg-gradient-to-r from-white to-neutral-500">
              Built for real-world signage
            </h1>
            <p className="max-w-[900px] text-muted-foreground md:text-xl/relaxed">
              Design faster, update instantly, and keep every screen looking professional.
            </p>
          </div>

          <BentoGrid className="max-w-6xl mx-auto mb-20">
            {features.map((item, i) => (
              <BentoGridItem
                key={i}
                title={item.title}
                description={item.description}
                header={item.header}
                icon={item.icon}
                className={i === 3 || i === 6 ? "md:col-span-2" : ""}
              />
            ))}
          </BentoGrid>
        </div>
      </main>
      <Footer />
    </div>
  );
}

const Skeleton = () => (
  <div className="flex flex-1 w-full h-full min-h-[6rem] rounded-xl bg-gradient-to-br from-neutral-200 dark:from-neutral-900 dark:to-neutral-800 to-neutral-100 animate-pulse"></div>
);

const features = [
  {
    title: "Menu Designer Studio",
    description: "Create beautiful menus and layouts with drag-and-drop building blocks and live previews.",
    header: <Skeleton />,
    icon: <Sparkles className="h-4 w-4 text-neutral-500" />,
  },
  {
    title: "Instant Updates",
    description: "Change a price once and every screen updates. No USB sticks, no reprinting.",
    header: <Skeleton />,
    icon: <LayoutDashboard className="h-4 w-4 text-neutral-500" />,
  },
  {
    title: "Multi-screen Management",
    description: "Group screens by store, zone, or department. Assign content in seconds.",
    header: <Skeleton />,
    icon: <Monitor className="h-4 w-4 text-neutral-500" />,
  },
  {
    title: "Smart Scheduling",
    description: "Schedule breakfast menus to switch to lunch automatically—perfect timing, every day.",
    header: <Skeleton />,
    icon: <Clock className="h-4 w-4 text-neutral-500" />,
  },
  {
    title: "Media Library",
    description: "Upload product photos and promos once, then reuse them across menus and campaigns.",
    header: <Skeleton />,
    icon: <ImageIcon className="h-4 w-4 text-neutral-500" />,
  },
  {
    title: "Business-grade Reliability",
    description: "Designed for 24/7 playback with secure access and dependable delivery.",
    header: <Skeleton />,
    icon: <ShieldCheck className="h-4 w-4 text-neutral-500" />,
  },
  {
    title: "Dynamic Lists (Pro)",
    description: "Power dashboards, schedules, and live lists (like spreadsheets) across multiple layout zones.",
    header: <Skeleton />,
    icon: <ListChecks className="h-4 w-4 text-neutral-500" />,
  },
];
