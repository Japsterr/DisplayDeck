import { Navbar } from "@/components/landing/Navbar";
import { Footer } from "@/components/landing/Footer";
import { BentoGrid, BentoGridItem } from "@/components/landing/BentoGrid";
import { Terminal, Zap, ShieldCheck, Smartphone, Globe, LayoutDashboard, Clock, Lock } from "lucide-react";

export default function FeaturesPage() {
  return (
    <div className="flex min-h-screen flex-col bg-background">
      <Navbar />
      <main className="flex-1 pt-24 pb-16">
        <div className="container px-4 md:px-6">
          <div className="flex flex-col items-center justify-center space-y-4 text-center mb-16">
            <h1 className="text-4xl font-bold tracking-tighter sm:text-6xl bg-clip-text text-transparent bg-gradient-to-r from-white to-neutral-500">
              Features
            </h1>
            <p className="max-w-[900px] text-muted-foreground md:text-xl/relaxed">
              Powerful tools for developers and content managers alike.
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
    title: "API-First Architecture",
    description: "Everything is an API endpoint. Automate your signage workflow with your favorite tools.",
    header: <Skeleton />,
    icon: <Terminal className="h-4 w-4 text-neutral-500" />,
  },
  {
    title: "Real-time WebSockets",
    description: "Push content updates instantly. No more waiting for polling intervals.",
    header: <Skeleton />,
    icon: <Zap className="h-4 w-4 text-neutral-500" />,
  },
  {
    title: "Role-Based Access",
    description: "Granular permissions for organizations, teams, and individual users.",
    header: <Skeleton />,
    icon: <ShieldCheck className="h-4 w-4 text-neutral-500" />,
  },
  {
    title: "Device Management",
    description: "Monitor health, reboot remotely, and take screenshots of what's playing.",
    header: <Skeleton />,
    icon: <Smartphone className="h-4 w-4 text-neutral-500" />,
  },
  {
    title: "Global CDN",
    description: "Media is cached at the edge for fast playback anywhere in the world.",
    header: <Skeleton />,
    icon: <Globe className="h-4 w-4 text-neutral-500" />,
  },
  {
    title: "Visual Dashboard",
    description: "A beautiful, dark-mode enabled dashboard for manual management.",
    header: <Skeleton />,
    icon: <LayoutDashboard className="h-4 w-4 text-neutral-500" />,
  },
  {
    title: "Smart Scheduling",
    description: "Schedule content by date, time, day of week, or even weather conditions (coming soon).",
    header: <Skeleton />,
    icon: <Clock className="h-4 w-4 text-neutral-500" />,
  },
];
