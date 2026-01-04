"use client"

import * as React from "react"
import {
  LayoutDashboard,
  ListTodo,
  Monitor,
  Megaphone,
  UtensilsCrossed,
  LayoutGrid,
  Library,
  BarChart3,
  Users,
  Settings,
  ScrollText,
  ChevronsLeft,
  ChevronsRight,
  LogOut,
  Sun,
  Moon,
} from "lucide-react"
import { useTheme } from "next-themes"

import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarGroup,
  SidebarGroupContent,
  SidebarGroupLabel,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarRail,
  useSidebar,
} from "@/components/ui/sidebar"
import { useRouter } from "next/navigation"

// Menu items.
const items = [
  {
    title: "Dashboard",
    url: "/dashboard",
    icon: LayoutDashboard,
  },
  {
    title: "Roadmap",
    url: "/dashboard/roadmap",
    icon: ListTodo,
  },
  {
    title: "Displays",
    url: "/dashboard/displays",
    icon: Monitor,
  },
  {
    title: "Campaigns",
    url: "/dashboard/campaigns",
    icon: Megaphone,
  },
  {
    title: "Analytics",
    url: "/dashboard/analytics",
    icon: BarChart3,
  },
  {
    title: "Audit Log",
    url: "/dashboard/audit-log",
    icon: ScrollText,
  },
  {
    title: "Menus",
    url: "/dashboard/menus",
    icon: UtensilsCrossed,
  },
  {
    title: "Info Boards",
    url: "/dashboard/infoboards",
    icon: LayoutGrid,
  },
  {
    title: "Media Library",
    url: "/dashboard/media",
    icon: Library,
  },
  {
    title: "Users",
    url: "/dashboard/users",
    icon: Users,
  },
  {
    title: "Settings",
    url: "/dashboard/settings",
    icon: Settings,
  },
]

export function AppSidebar({ ...props }: React.ComponentProps<typeof Sidebar>) {
  const router = useRouter();
  const { state, toggleSidebar } = useSidebar();
  const { theme, setTheme } = useTheme();
  const [mounted, setMounted] = React.useState(false);

  React.useEffect(() => {
    setMounted(true);
  }, []);

  const handleLogout = () => {
    localStorage.removeItem("token");
    localStorage.removeItem("user");
    // Force a hard reload to clear any in-memory state
    window.location.href = "/login";
  };

  const toggleTheme = () => {
    setTheme(theme === "dark" ? "light" : "dark");
  };

  return (
    <Sidebar collapsible="icon" {...props}>
      <SidebarHeader>
        <div className="flex items-center gap-2 px-2 py-2">
          <div className="flex aspect-square size-8 items-center justify-center rounded-lg bg-sidebar-primary text-sidebar-primary-foreground">
            <Monitor className="size-4" />
          </div>
          <div className="grid flex-1 text-left text-sm leading-tight">
            <span className="truncate font-semibold">DisplayDeck</span>
            <span className="truncate text-xs">Enterprise</span>
          </div>
        </div>
      </SidebarHeader>
      <SidebarContent>
        <SidebarGroup>
          <SidebarGroupLabel>Platform</SidebarGroupLabel>
          <SidebarGroupContent>
            <SidebarMenu>
              {items.map((item) => (
                <SidebarMenuItem key={item.title}>
                  <SidebarMenuButton asChild tooltip={item.title}>
                    <a href={item.url}>
                      <item.icon />
                      <span>{item.title}</span>
                    </a>
                  </SidebarMenuButton>
                </SidebarMenuItem>
              ))}
            </SidebarMenu>
          </SidebarGroupContent>
        </SidebarGroup>
      </SidebarContent>
      <SidebarFooter>
        <SidebarMenu>
          <SidebarMenuItem>
            <SidebarMenuButton
              onClick={toggleTheme}
              tooltip={mounted ? (theme === "dark" ? "Switch to light mode" : "Switch to dark mode") : "Toggle theme"}
            >
              {mounted && theme === "dark" ? <Sun /> : <Moon />}
              <span>{mounted ? (theme === "dark" ? "Light Mode" : "Dark Mode") : "Theme"}</span>
            </SidebarMenuButton>
          </SidebarMenuItem>
          <SidebarMenuItem>
            <SidebarMenuButton
              onClick={toggleSidebar}
              tooltip={state === "collapsed" ? "Expand sidebar" : "Collapse sidebar"}
            >
              {state === "collapsed" ? <ChevronsRight /> : <ChevronsLeft />}
              <span>{state === "collapsed" ? "Expand" : "Collapse"}</span>
            </SidebarMenuButton>
          </SidebarMenuItem>
          <SidebarMenuItem>
            <SidebarMenuButton onClick={handleLogout} tooltip="Logout">
              <LogOut />
              <span>Logout</span>
            </SidebarMenuButton>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarFooter>
      <SidebarRail />
    </Sidebar>
  )
}
