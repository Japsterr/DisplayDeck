"use client";

import { useEffect, useMemo, useRef, useState, type ChangeEvent } from "react";
import { useParams, useRouter } from "next/navigation";
import { toast } from "sonner";
import {
  ArrowLeft,
  Plus,
  Save,
  Trash2,
  ExternalLink,
  Copy,
  RefreshCw,
  Settings2,
  Upload,
  Image as ImageIcon,
} from "lucide-react";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Separator } from "@/components/ui/separator";
import { Textarea } from "../../../../../components/ui/textarea";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Switch } from "@/components/ui/switch";

const APP_VERSION = process.env.NEXT_PUBLIC_APP_VERSION || "dev";

type ThemeConfig = Record<string, unknown>;

interface Menu {
  Id: number;
  OrganizationId: number;
  Name: string;
  Orientation: string;
  TemplateKey: string;
  PublicToken: string;
  ThemeConfig?: ThemeConfig;
}

interface MenuSection {
  Id: number;
  MenuId: number;
  Name: string;
  DisplayOrder: number;
}

interface MenuItem {
  Id: number;
  MenuSectionId: number;
  Name: string;
  Sku: string | null;
  Description: string | null;
  ImageUrl: string | null;
  PriceCents: number | null;
  IsAvailable: boolean;
  DisplayOrder: number;
}

interface MediaFile {
  Id: number;
  FileName: string;
  FileType: string;
  Orientation: string;
  StorageURL: string;
  CreatedAt: string;
}

const MEDIA_REF_PREFIX = "mediafile:";

function makeMediaRef(mediaFileId: number) {
  return `${MEDIA_REF_PREFIX}${mediaFileId}`;
}

function parseMediaRef(raw: string | null | undefined): number | null {
  const s = (raw || "").trim();
  if (!s.toLowerCase().startsWith(MEDIA_REF_PREFIX)) return null;
  const n = parseInt(s.slice(MEDIA_REF_PREFIX.length), 10);
  return Number.isFinite(n) && n > 0 ? n : null;
}

function getApiUrl() {
  return process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";
}

function getAuth() {
  const token = localStorage.getItem("token");
  const userStr = localStorage.getItem("user");
  if (!token || !userStr) return null;
  try {
    const user = JSON.parse(userStr);
    const orgId = user?.OrganizationId;
    if (!orgId) return null;
    return { token, orgId };
  } catch {
    return null;
  }
}

function formatCurrencyZarFromCents(priceCents: number) {
  try {
    return new Intl.NumberFormat("en-ZA", { style: "currency", currency: "ZAR" }).format(priceCents / 100);
  } catch {
    // fallback
    return `R ${(priceCents / 100).toFixed(2)}`;
  }
}

function readThemeString(theme: ThemeConfig, key: string, fallback: string) {
  const v = theme?.[key];
  return typeof v === "string" && v.trim() ? v : fallback;
}

function readThemeColumns(theme: ThemeConfig): "auto" | "1" | "2" | "3" {
  const raw = theme?.layoutColumns;
  if (raw === 1 || raw === "1") return "1";
  if (raw === 2 || raw === "2") return "2";
  if (raw === 3 || raw === "3") return "3";
  return "auto";
}

function parseCsvTable(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let field = "";
  let inQuotes = false;

  for (let i = 0; i < text.length; i++) {
    const ch = text[i];

    if (inQuotes) {
      if (ch === '"') {
        const next = text[i + 1];
        if (next === '"') {
          field += '"';
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field += ch;
      }
      continue;
    }

    if (ch === '"') {
      inQuotes = true;
    } else if (ch === ",") {
      row.push(field);
      field = "";
    } else if (ch === "\n") {
      row.push(field);
      field = "";
      if (row.some((c) => c.trim() !== "")) rows.push(row);
      row = [];
    } else if (ch === "\r") {
      // ignore (CRLF handled by \n)
    } else {
      field += ch;
    }
  }

  if (field.length > 0 || row.length > 0) {
    row.push(field);
    if (row.some((c) => c.trim() !== "")) rows.push(row);
  }

  return rows;
}

function csvToRecords(text: string): Array<Record<string, string>> {
  const table = parseCsvTable(text || "");
  if (table.length === 0) return [];
  const headers = table[0].map((h) => h.trim());
  const out: Array<Record<string, string>> = [];

  for (const row of table.slice(1)) {
    const rec: Record<string, string> = {};
    for (let i = 0; i < headers.length; i++) {
      const key = headers[i];
      if (!key) continue;
      rec[key] = (row[i] ?? "").trim();
    }
    if (Object.values(rec).some((v) => v.trim() !== "")) out.push(rec);
  }
  return out;
}

function getFirst(rec: Record<string, string>, keys: string[]) {
  for (const k of keys) {
    const v = rec[k];
    if (typeof v === "string" && v.trim()) return v.trim();
  }
  return "";
}

function parseBoolOrDefault(value: string, defaultValue: boolean) {
  const v = (value || "").trim().toLowerCase();
  if (!v) return defaultValue;
  if (["true", "1", "yes", "y"].includes(v)) return true;
  if (["false", "0", "no", "n"].includes(v)) return false;
  return defaultValue;
}

function parsePriceCents(value: string): number | null {
  const v = (value || "").trim();
  if (!v) return null;
  const normalized = v.replace(/[^0-9.\-]/g, "");
  const n = parseFloat(normalized);
  if (!isFinite(n)) return null;
  return Math.round(n * 100);
}

type CsvDryRunRowStatus = "ok" | "error";

type CsvImportPlanRow = {
  rowNumber: number;
  sectionName: string;
  name: string;
  sku: string;
  description: string;
  imageUrl: string;
  priceCents: number | null;
  isAvailable: boolean;
  resolvedOrder: number;
  willCreateSection: boolean;
  status: CsvDryRunRowStatus;
  message?: string;
};

type CsvDryRunResult = {
  sourceText: string;
  totalRows: number;
  okRows: number;
  errorRows: number;
  newSections: string[];
  plan: CsvImportPlanRow[];
};

function analyzeCsvImportPlan(args: {
  csvText: string;
  existingSections: MenuSection[];
  itemsBySection: Record<number, MenuItem[]>;
}): CsvDryRunResult {
  const { csvText, existingSections, itemsBySection } = args;
  const records = csvToRecords(csvText);

  const existingSectionNames = new Set(existingSections.map((s) => s.Name.trim()));
  const nextItemOrderBySectionName = new Map<string, number>();
  for (const s of existingSections) {
    const items = itemsBySection[s.Id] || [];
    const next = items.length ? Math.max(...items.map((i) => i.DisplayOrder)) + 1 : 1;
    nextItemOrderBySectionName.set(s.Name.trim(), next);
  }

  const newSectionsSet = new Set<string>();
  const plan: CsvImportPlanRow[] = [];
  let okRows = 0;
  let errorRows = 0;

  for (let idx = 0; idx < records.length; idx++) {
    const rec = records[idx];
    const rowNumber = idx + 2; // header row is 1

    const sectionName = getFirst(rec, ["Section", "SectionName", "Category", "Group"]).trim();
    const name = getFirst(rec, ["Name", "Item", "ItemName"]).trim();
    const sku = getFirst(rec, ["Sku", "SKU"]).trim();
    const description = getFirst(rec, ["Description", "Desc"]).trim();
    const imageUrl = getFirst(rec, ["ImageUrl", "ImageURL", "Image", "PhotoUrl", "PhotoURL"]).trim();

    const rawPrice = getFirst(rec, ["Price", "PriceZar", "ZAR", "Amount"]);
    const rawPriceCents = getFirst(rec, ["PriceCents"]);

    const priceCentsFromZar = rawPrice ? parsePriceCents(rawPrice) : null;
    const priceCentsDirect = (() => {
      if (!rawPriceCents) return null;
      const n = parseInt(rawPriceCents, 10);
      return isFinite(n) ? n : null;
    })();

    const isAvailable = parseBoolOrDefault(getFirst(rec, ["IsAvailable", "Available"]), true);

    const displayOrder = (() => {
      const v = getFirst(rec, ["DisplayOrder", "Order"]);
      if (!v) return null;
      const n = parseInt(v, 10);
      return isFinite(n) ? n : null;
    })();

    const willCreateSection = !!sectionName && !existingSectionNames.has(sectionName);
    if (willCreateSection) newSectionsSet.add(sectionName);

    const invalidRequired = !sectionName || !name;
    const invalidPriceCents = !!rawPriceCents && priceCentsDirect === null;
    const invalidPrice = !!rawPrice && priceCentsFromZar === null;

    if (invalidRequired) {
      errorRows++;
      plan.push({
        rowNumber,
        sectionName,
        name,
        sku,
        description,
        imageUrl,
        priceCents: null,
        isAvailable,
        resolvedOrder: displayOrder ?? 0,
        willCreateSection,
        status: "error",
        message: "Missing required Section or Name",
      });
      continue;
    }

    if (invalidPriceCents) {
      errorRows++;
      plan.push({
        rowNumber,
        sectionName,
        name,
        sku,
        description,
        imageUrl,
        priceCents: null,
        isAvailable,
        resolvedOrder: displayOrder ?? 0,
        willCreateSection,
        status: "error",
        message: "Invalid PriceCents (must be an integer)",
      });
      continue;
    }

    if (invalidPrice) {
      errorRows++;
      plan.push({
        rowNumber,
        sectionName,
        name,
        sku,
        description,
        imageUrl,
        priceCents: null,
        isAvailable,
        resolvedOrder: displayOrder ?? 0,
        willCreateSection,
        status: "error",
        message: "Invalid Price (expected ZAR like 89.99)",
      });
      continue;
    }

    const nextOrder = nextItemOrderBySectionName.get(sectionName) ?? 1;
    const resolvedOrder = displayOrder ?? nextOrder;
    if (displayOrder == null) nextItemOrderBySectionName.set(sectionName, resolvedOrder + 1);

    okRows++;
    plan.push({
      rowNumber,
      sectionName,
      name,
      sku,
      description,
      imageUrl,
      priceCents: priceCentsDirect ?? priceCentsFromZar,
      isAvailable,
      resolvedOrder,
      willCreateSection,
      status: "ok",
    });
  }

  return {
    sourceText: csvText,
    totalRows: records.length,
    okRows,
    errorRows,
    newSections: Array.from(newSectionsSet).sort((a, b) => a.localeCompare(b)),
    plan,
  };
}

export default function MenuEditorPage() {
  const params = useParams();
  const router = useRouter();
  const menuId = parseInt(params.id as string);

  const [menu, setMenu] = useState<Menu | null>(null);
  const [sections, setSections] = useState<MenuSection[]>([]);
  const [itemsBySection, setItemsBySection] = useState<Record<number, MenuItem[]>>({});
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const [savingMenu, setSavingMenu] = useState(false);
  const [themeJsonText, setThemeJsonText] = useState<string>("{}");

  const resetThemeConfig = () => {
    setThemeJsonText("{}\n");
    toast.success("ThemeConfig reset");
  };

  const updateThemeJson = (updater: (theme: ThemeConfig) => ThemeConfig) => {
    let current: ThemeConfig = {};
    try {
      current = JSON.parse(themeJsonText || "{}") as ThemeConfig;
    } catch {
      toast.error("ThemeConfig must be valid JSON (fix it or clear it) before using theme controls");
      return;
    }
    const next = updater(current || {});
    setThemeJsonText(JSON.stringify(next, null, 2));
  };

  const [isAddSectionOpen, setIsAddSectionOpen] = useState(false);
  const [newSection, setNewSection] = useState({ name: "", displayOrder: 0 });

  const [addItemSectionId, setAddItemSectionId] = useState<number | null>(null);
  const [newItem, setNewItem] = useState({ name: "", sku: "", description: "", imageUrl: "", price: "", isAvailable: true, displayOrder: 0 });

  const [mediaLibrary, setMediaLibrary] = useState<MediaFile[]>([]);
  const [mediaLoading, setMediaLoading] = useState(false);
  const [mediaQuery, setMediaQuery] = useState("");
  const [isMediaPickerOpen, setIsMediaPickerOpen] = useState(false);
  const [mediaPreviewUrls, setMediaPreviewUrls] = useState<Record<number, string>>({});
  const [mediaPickerTarget, setMediaPickerTarget] = useState<
    | { kind: "new" }
    | { kind: "existing"; sectionId: number; itemId: number }
    | { kind: "menuBackground" }
    | { kind: "menuLogo" }
    | { kind: "sectionImage"; sectionId: number }
    | null
  >(null);
  const [uploadingImage, setUploadingImage] = useState(false);
  const uploadFileRef = useRef<HTMLInputElement>(null);

  const ensureMediaPreviewUrl = async (mediaFileId: number) => {
    if (mediaPreviewUrls[mediaFileId]) return;
    const auth = getAuth();
    if (!auth) return;
    try {
      const apiUrl = getApiUrl();
      const res = await fetch(`${apiUrl}/media-files/${mediaFileId}/download-url`, {
        headers: { "X-Auth-Token": auth.token },
      });
      if (!res.ok) return;
      const data = (await res.json()) as { DownloadUrl?: string };
      const url = (data?.DownloadUrl || "").trim();
      if (!url) return;
      setMediaPreviewUrls((prev) => (prev[mediaFileId] ? prev : { ...prev, [mediaFileId]: url }));
    } catch {
      // ignore preview failures
    }
  };

  const resolvePreviewSrc = (raw: string | null | undefined) => {
    const id = parseMediaRef(raw);
    if (!id) return (raw || "").trim();
    const url = mediaPreviewUrls[id];
    if (!url) {
      void ensureMediaPreviewUrl(id);
      return "";
    }
    return url;
  };

  const publicBaseUrl = useMemo(() => {
    if (typeof window === "undefined") return "";
    return window.location.origin;
  }, []);

  const publicUrl = useMemo(() => {
    if (!menu) return "";
    return `${publicBaseUrl}/display/menu/${menu.PublicToken}`;
  }, [menu, publicBaseUrl]);

  const [showEmbeddedPreview, setShowEmbeddedPreview] = useState(false);
  const [previewNonce, setPreviewNonce] = useState(0);

  const [isImportCsvOpen, setIsImportCsvOpen] = useState(false);
  const [csvText, setCsvText] = useState<string>("");
  const [csvDryRun, setCsvDryRun] = useState<CsvDryRunResult | null>(null);
  const [dryRunningCsv, setDryRunningCsv] = useState(false);
  const [importingCsv, setImportingCsv] = useState(false);

  const previewUrl = useMemo(() => {
    if (!publicUrl) return "";
    return `${publicUrl}?v=${previewNonce}`;
  }, [publicUrl, previewNonce]);

  const parsedTheme = useMemo(() => {
    try {
      return JSON.parse(themeJsonText || "{}") as ThemeConfig;
    } catch {
      return null;
    }
  }, [themeJsonText]);

  const fetchAll = async () => {
    const auth = getAuth();
    if (!auth) {
      router.push("/login");
      return;
    }

    const apiUrl = getApiUrl();
    const headers = { "X-Auth-Token": auth.token };

    const menuRes = await fetch(`${apiUrl}/menus/${menuId}`, { headers });
    if (menuRes.status === 401) {
      router.push("/login");
      return;
    }
    if (!menuRes.ok) throw new Error(await menuRes.text());
    const m = (await menuRes.json()) as Menu;
    if (m.OrganizationId !== auth.orgId) throw new Error("Forbidden");
    setMenu(m);

    const theme = (m.ThemeConfig ?? {}) as ThemeConfig;
    setThemeJsonText(JSON.stringify(theme, null, 2));

    const secRes = await fetch(`${apiUrl}/menus/${menuId}/sections`, { headers });
    if (!secRes.ok) throw new Error(await secRes.text());
    const secData = await secRes.json();
    const secList = (secData.value || []) as MenuSection[];
    setSections(secList);

    const itemPairs = await Promise.all(
      secList.map(async (s) => {
        const res = await fetch(`${apiUrl}/menu-sections/${s.Id}/items`, { headers });
        if (!res.ok) return { sectionId: s.Id, items: [] as MenuItem[] };
        const data = await res.json();
        return { sectionId: s.Id, items: (data.value || []) as MenuItem[] };
      })
    );

    const map: Record<number, MenuItem[]> = {};
    for (const p of itemPairs) map[p.sectionId] = p.items;
    setItemsBySection(map);
  };

  const fetchMediaLibrary = async (): Promise<MediaFile[] | null> => {
    const auth = getAuth();
    if (!auth) {
      router.push("/login");
      return null;
    }

    try {
      setMediaLoading(true);
      const apiUrl = getApiUrl();
      const res = await fetch(`${apiUrl}/organizations/${auth.orgId}/media-files`, {
        headers: { "X-Auth-Token": auth.token },
      });
      if (res.status === 401) {
        router.push("/login");
        return null;
      }
      if (!res.ok) throw new Error(await res.text());
      const data = await res.json();
      const list = (data.value || []) as MediaFile[];
      setMediaLibrary(list);
      return list;
    } catch (e) {
      console.error(e);
      toast.error("Failed to load media library");
      return null;
    } finally {
      setMediaLoading(false);
    }
  };

  const openMediaPicker = async (
    target:
      | { kind: "new" }
      | { kind: "existing"; sectionId: number; itemId: number }
      | { kind: "menuBackground" }
      | { kind: "menuLogo" }
      | { kind: "sectionImage"; sectionId: number }
  ) => {
    setMediaPickerTarget(target);
    setIsMediaPickerOpen(true);
    if (mediaLibrary.length === 0) await fetchMediaLibrary();
  };

  useEffect(() => {
    if (!isMediaPickerOpen) return;
    const q = mediaQuery.trim().toLowerCase();
    const visible = mediaLibrary
      .filter((m) => (m.FileType || "").startsWith("image/"))
      .filter((m) => {
        if (!q) return true;
        return (m.FileName || "").toLowerCase().includes(q);
      })
      .slice(0, 36);
    for (const m of visible) void ensureMediaPreviewUrl(m.Id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isMediaPickerOpen, mediaQuery, mediaLibrary]);

  const applyImageUrlToTarget = async (imageUrl: string | null) => {
    const t = mediaPickerTarget;
    if (!t) return;

    if (t.kind === "new") {
      setNewItem((p) => ({ ...p, imageUrl: imageUrl || "" }));
      return;
    }

    if (t.kind === "menuBackground") {
      updateThemeJson((theme) => {
        const next = { ...(theme || {}) } as any;
        if (imageUrl) next.backgroundImageUrl = imageUrl;
        else delete next.backgroundImageUrl;
        return next as ThemeConfig;
      });
      return;
    }

    if (t.kind === "menuLogo") {
      updateThemeJson((theme) => {
        const next = { ...(theme || {}) } as any;
        if (imageUrl) next.logoUrl = imageUrl;
        else delete next.logoUrl;
        return next as ThemeConfig;
      });
      return;
    }

    if (t.kind === "sectionImage") {
      const sectionId = t.sectionId;
      updateThemeJson((theme) => {
        const next = { ...(theme || {}) } as any;
        const current = next.sectionImages;
        const map: Record<string, string> =
          current && typeof current === "object" && !Array.isArray(current)
            ? { ...(current as Record<string, string>) }
            : {};
        if (imageUrl) map[String(sectionId)] = imageUrl;
        else delete map[String(sectionId)];

        if (Object.keys(map).length === 0) delete next.sectionImages;
        else next.sectionImages = map;
        return next as ThemeConfig;
      });
      return;
    }

    const { sectionId, itemId } = t;
    const item = (itemsBySection[sectionId] || []).find((x) => x.Id === itemId);
    if (!item) return;

    const updated: MenuItem = { ...item, ImageUrl: imageUrl };
    setItemsBySection((prev) => ({
      ...prev,
      [sectionId]: (prev[sectionId] || []).map((x) => (x.Id === itemId ? updated : x)),
    }));
    await handleUpdateItem(updated);
  };

  const uploadImageAndSelect = async () => {
    const auth = getAuth();
    if (!auth) {
      router.push("/login");
      return;
    }

    const file = uploadFileRef.current?.files?.[0];
    if (!file) {
      toast.error("Please choose an image file");
      return;
    }

    try {
      setUploadingImage(true);
      const apiUrl = getApiUrl();
      const orientation = menu?.Orientation || "Landscape";

      const uploadUrlRes = await fetch(`${apiUrl}/media-files/upload-url`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": auth.token,
        },
        body: JSON.stringify({
          OrganizationId: auth.orgId,
          FileName: file.name,
          FileType: file.type || "application/octet-stream",
          ContentLength: file.size,
          Orientation: orientation,
        }),
      });

      if (!uploadUrlRes.ok) throw new Error(await uploadUrlRes.text());
      const uploadData = (await uploadUrlRes.json()) as { UploadUrl: string; MediaFileId: number };

      const putRes = await fetch(uploadData.UploadUrl, {
        method: "PUT",
        body: file,
        headers: { "Content-Type": file.type || "application/octet-stream" },
      });
      if (!putRes.ok) throw new Error(await putRes.text());

      // Store a stable reference instead of a raw storage URL (buckets are private by default).
      await applyImageUrlToTarget(makeMediaRef(uploadData.MediaFileId));
      void ensureMediaPreviewUrl(uploadData.MediaFileId);
      setIsMediaPickerOpen(false);
    } catch (e) {
      console.error(e);
      toast.error("Upload failed");
    } finally {
      setUploadingImage(false);
      if (uploadFileRef.current) uploadFileRef.current.value = "";
    }
  };

  const refresh = async () => {
    try {
      setRefreshing(true);
      await fetchAll();
      toast.success("Refreshed");
    } catch (e) {
      console.error(e);
      toast.error("Failed to refresh menu");
    } finally {
      setRefreshing(false);
    }
  };

  useEffect(() => {
    const run = async () => {
      try {
        setLoading(true);
        await fetchAll();
      } catch (e) {
        console.error(e);
        toast.error("Failed to load menu");
      } finally {
        setLoading(false);
      }
    };

    if (menuId) run();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [menuId]);

  const handleSaveMenu = async () => {
    if (!menu) return;

    let theme: ThemeConfig = {};
    try {
      theme = JSON.parse(themeJsonText || "{}") as ThemeConfig;
    } catch {
      toast.error("ThemeConfig must be valid JSON");
      return;
    }

    try {
      setSavingMenu(true);
      const auth = getAuth();
      if (!auth) return;
      const apiUrl = getApiUrl();

      const res = await fetch(`${apiUrl}/menus/${menu.Id}`, {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": auth.token,
        },
        body: JSON.stringify({
          Name: menu.Name,
          Orientation: menu.Orientation,
          TemplateKey: menu.TemplateKey,
          ThemeConfig: theme,
        }),
      });

      if (!res.ok) throw new Error(await res.text());
      const updated = (await res.json()) as Menu;
      setMenu(updated);
      toast.success("Menu saved");
    } catch (e) {
      console.error(e);
      toast.error("Failed to save menu");
    } finally {
      setSavingMenu(false);
    }
  };

  const handleDeleteMenu = async () => {
    if (!menu) return;
    if (!confirm("Delete this menu? This cannot be undone.")) return;

    try {
      const auth = getAuth();
      if (!auth) return;
      const apiUrl = getApiUrl();

      const res = await fetch(`${apiUrl}/menus/${menu.Id}`, {
        method: "DELETE",
        headers: { "X-Auth-Token": auth.token },
      });
      if (!res.ok) throw new Error(await res.text());

      toast.success("Menu deleted");
      router.push("/dashboard/menus");
    } catch (e) {
      console.error(e);
      toast.error("Failed to delete menu");
    }
  };

  const handleCreateSection = async () => {
    if (!menu) return;
    if (!newSection.name.trim()) {
      toast.error("Section name is required");
      return;
    }

    try {
      const auth = getAuth();
      if (!auth) return;
      const apiUrl = getApiUrl();

      const order = newSection.displayOrder || (sections.length ? Math.max(...sections.map((s) => s.DisplayOrder)) + 1 : 1);
      const res = await fetch(`${apiUrl}/menus/${menu.Id}/sections`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": auth.token,
        },
        body: JSON.stringify({ Name: newSection.name.trim(), DisplayOrder: order }),
      });
      if (!res.ok) throw new Error(await res.text());
      const created = (await res.json()) as MenuSection;
      setSections((prev) => [...prev, created].sort((a, b) => a.DisplayOrder - b.DisplayOrder));
      setItemsBySection((prev) => ({ ...prev, [created.Id]: [] }));
      setIsAddSectionOpen(false);
      setNewSection({ name: "", displayOrder: 0 });
      toast.success("Section created");
    } catch (e) {
      console.error(e);
      toast.error("Failed to create section");
    }
  };

  const handleUpdateSection = async (section: MenuSection) => {
    try {
      const auth = getAuth();
      if (!auth) return;
      const apiUrl = getApiUrl();

      const res = await fetch(`${apiUrl}/menu-sections/${section.Id}`, {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": auth.token,
        },
        body: JSON.stringify({ Name: section.Name, DisplayOrder: section.DisplayOrder }),
      });
      if (!res.ok) throw new Error(await res.text());
      const updated = (await res.json()) as MenuSection;

      setSections((prev) =>
        prev
          .map((s) => (s.Id === updated.Id ? updated : s))
          .sort((a, b) => a.DisplayOrder - b.DisplayOrder)
      );
    } catch (e) {
      console.error(e);
      toast.error("Failed to update section");
    }
  };

  const handleDeleteSection = async (sectionId: number) => {
    if (!confirm("Delete this section and all its items?")) return;

    try {
      const auth = getAuth();
      if (!auth) return;
      const apiUrl = getApiUrl();

      const res = await fetch(`${apiUrl}/menu-sections/${sectionId}`, {
        method: "DELETE",
        headers: { "X-Auth-Token": auth.token },
      });
      if (!res.ok) throw new Error(await res.text());

      setSections((prev) => prev.filter((s) => s.Id !== sectionId));
      setItemsBySection((prev) => {
        const copy = { ...prev };
        delete copy[sectionId];
        return copy;
      });
      toast.success("Section deleted");
    } catch (e) {
      console.error(e);
      toast.error("Failed to delete section");
    }
  };

  const openAddItem = (sectionId: number) => {
    const existing = itemsBySection[sectionId] || [];
    const order = existing.length ? Math.max(...existing.map((i) => i.DisplayOrder)) + 1 : 1;
    setNewItem({ name: "", sku: "", description: "", imageUrl: "", price: "", isAvailable: true, displayOrder: order });
    setAddItemSectionId(sectionId);
  };

  const handleCreateItem = async () => {
    if (!addItemSectionId) return;
    if (!newItem.name.trim()) {
      toast.error("Item name is required");
      return;
    }

    const priceText = newItem.price.trim();
    const hasPrice = priceText !== "";
    const priceCents = hasPrice ? Math.round(parseFloat(priceText) * 100) : 0;

    if (hasPrice && (!isFinite(priceCents) || priceCents < 0)) {
      toast.error("Invalid price");
      return;
    }

    try {
      const auth = getAuth();
      if (!auth) return;
      const apiUrl = getApiUrl();

      const res = await fetch(`${apiUrl}/menu-sections/${addItemSectionId}/items`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": auth.token,
        },
        body: JSON.stringify({
          Name: newItem.name.trim(),
          Sku: newItem.sku.trim() || null,
          Description: newItem.description.trim() || null,
          ImageUrl: newItem.imageUrl.trim() || null,
          PriceCents: hasPrice ? priceCents : null,
          IsAvailable: newItem.isAvailable,
          DisplayOrder: newItem.displayOrder,
        }),
      });
      if (!res.ok) throw new Error(await res.text());
      const created = (await res.json()) as MenuItem;

      setItemsBySection((prev) => {
        const list = [...(prev[addItemSectionId] || []), created].sort((a, b) => a.DisplayOrder - b.DisplayOrder);
        return { ...prev, [addItemSectionId]: list };
      });
      setAddItemSectionId(null);
      toast.success("Item created");
    } catch (e) {
      console.error(e);
      let msg = "Failed to create item";
      if (e instanceof Error && e.message) msg = e.message;
      // If the API returned our standard JSONError payload, prefer its `message` field.
      try {
        const parsed = JSON.parse(msg) as { message?: string };
        if (parsed?.message) msg = parsed.message;
      } catch {
        // ignore
      }
      toast.error(msg);
    }
  };

  const handleImportCsv = async () => {
    if (!menu) return;

    if (!csvDryRun || csvDryRun.sourceText !== csvText) {
      toast.error("Run Dry run first");
      return;
    }

    if (csvDryRun.okRows === 0) {
      toast.error("Dry run found no valid rows to import");
      return;
    }

    const planRows = csvDryRun.plan.filter((r) => r.status === "ok");
    if (planRows.length === 0) {
      toast.error("Nothing to import");
      return;
    }

    try {
      setImportingCsv(true);
      const auth = getAuth();
      if (!auth) return;
      const apiUrl = getApiUrl();

      const sectionNameToId = new Map<string, number>();
      for (const s of sections) sectionNameToId.set(s.Name.trim(), s.Id);

      let nextSectionOrder = sections.length ? Math.max(...sections.map((s) => s.DisplayOrder)) + 1 : 1;
      const nextItemOrderBySection = new Map<number, number>();
      for (const s of sections) {
        const items = itemsBySection[s.Id] || [];
        const next = items.length ? Math.max(...items.map((i) => i.DisplayOrder)) + 1 : 1;
        nextItemOrderBySection.set(s.Id, next);
      }

      let createdCount = 0;
      const errors: string[] = [];

      for (const row of planRows) {
        let sectionId = sectionNameToId.get(row.sectionName);
        if (!sectionId) {
          // Create missing section
          const secRes = await fetch(`${apiUrl}/menus/${menu.Id}/sections`, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "X-Auth-Token": auth.token,
            },
            body: JSON.stringify({ Name: row.sectionName, DisplayOrder: nextSectionOrder }),
          });
          if (!secRes.ok) {
            if (errors.length < 10) errors.push(`Failed to create section '${row.sectionName}': ${await secRes.text()}`);
            continue;
          }
          const createdSection = (await secRes.json()) as MenuSection;
          sectionId = createdSection.Id;
          sectionNameToId.set(row.sectionName, sectionId);
          nextItemOrderBySection.set(sectionId, 1);
          nextSectionOrder++;
        }

        const resolvedOrder = row.resolvedOrder || (nextItemOrderBySection.get(sectionId) ?? 1);
        nextItemOrderBySection.set(sectionId, resolvedOrder + 1);

        const itemRes = await fetch(`${apiUrl}/menu-sections/${sectionId}/items`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Auth-Token": auth.token,
          },
          body: JSON.stringify({
            Name: row.name,
            Sku: row.sku || null,
            Description: row.description || null,
            ImageUrl: row.imageUrl || null,
            PriceCents: row.priceCents,
            IsAvailable: row.isAvailable,
            DisplayOrder: resolvedOrder,
          }),
        });

        if (!itemRes.ok) {
          if (errors.length < 10) errors.push(`Failed to create item '${row.name}': ${await itemRes.text()}`);
          continue;
        }

        createdCount++;
      }

      await fetchAll();

      if (createdCount > 0) toast.success(`Imported ${createdCount} item${createdCount === 1 ? "" : "s"}`);
      if (errors.length > 0) toast.error(`Import had ${errors.length} error${errors.length === 1 ? "" : "s"}`);

      if (errors.length > 0) console.warn("CSV import errors", errors);

      setIsImportCsvOpen(false);
      setCsvText("");
      setCsvDryRun(null);
    } catch (e) {
      console.error(e);
      toast.error("CSV import failed");
    } finally {
      setImportingCsv(false);
    }
  };

  const handleDryRunCsv = async () => {
    try {
      setDryRunningCsv(true);
      const dryRun = analyzeCsvImportPlan({ csvText, existingSections: sections, itemsBySection });
      setCsvDryRun(dryRun);

      if (dryRun.totalRows === 0) {
        toast.error("CSV is empty (or missing headers)");
        return;
      }

      if (dryRun.errorRows > 0) toast.error(`Dry run found ${dryRun.errorRows} error${dryRun.errorRows === 1 ? "" : "s"}`);
      if (dryRun.okRows > 0) toast.success(`Dry run OK: ${dryRun.okRows} row${dryRun.okRows === 1 ? "" : "s"} ready`);
    } catch (e) {
      console.error(e);
      toast.error("Dry run failed");
    } finally {
      setDryRunningCsv(false);
    }
  };

  const handleUpdateItem = async (item: MenuItem) => {
    try {
      const auth = getAuth();
      if (!auth) return;
      const apiUrl = getApiUrl();

      const res = await fetch(`${apiUrl}/menu-items/${item.Id}`, {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": auth.token,
        },
        body: JSON.stringify({
          Name: item.Name,
          Sku: item.Sku,
          Description: item.Description,
          ImageUrl: item.ImageUrl,
          PriceCents: item.PriceCents,
          IsAvailable: item.IsAvailable,
          DisplayOrder: item.DisplayOrder,
        }),
      });
      if (!res.ok) throw new Error(await res.text());
      const updated = (await res.json()) as MenuItem;

      setItemsBySection((prev) => {
        const list = (prev[updated.MenuSectionId] || []).map((i) => (i.Id === updated.Id ? updated : i)).sort((a, b) => a.DisplayOrder - b.DisplayOrder);
        return { ...prev, [updated.MenuSectionId]: list };
      });
    } catch (e) {
      console.error(e);
      toast.error("Failed to update item");
    }
  };

  const handleDeleteItem = async (item: MenuItem) => {
    if (!confirm("Delete this item?")) return;

    try {
      const auth = getAuth();
      if (!auth) return;
      const apiUrl = getApiUrl();

      const res = await fetch(`${apiUrl}/menu-items/${item.Id}`, {
        method: "DELETE",
        headers: { "X-Auth-Token": auth.token },
      });
      if (!res.ok) throw new Error(await res.text());

      setItemsBySection((prev) => {
        const list = (prev[item.MenuSectionId] || []).filter((i) => i.Id !== item.Id);
        return { ...prev, [item.MenuSectionId]: list };
      });
      toast.success("Item deleted");
    } catch (e) {
      console.error(e);
      toast.error("Failed to delete item");
    }
  };

  const handleCopyPublicUrl = async () => {
    if (!publicUrl) return;
    try {
      await navigator.clipboard.writeText(publicUrl);
      toast.success("Copied public URL");
    } catch {
      toast.error("Failed to copy");
    }
  };

  const handleDuplicateMenu = async () => {
    if (!menu) return;
    try {
      const auth = getAuth();
      if (!auth) return;

      const apiUrl = getApiUrl();
      const res = await fetch(`${apiUrl}/menus/${menu.Id}/duplicate`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": auth.token,
        },
        body: JSON.stringify({}),
      });

      if (!res.ok) throw new Error(await res.text());
      const created = (await res.json()) as Menu;
      toast.success("Menu duplicated");
      router.push(`/dashboard/menus/${created.Id}`);
    } catch (e) {
      console.error(e);
      toast.error("Failed to duplicate menu");
    }
  };

  if (loading) return <div className="p-8 text-center">Loading menu...</div>;
  if (!menu) return <div className="p-8 text-center">Menu not found</div>;

  return (
    <div className="flex flex-col gap-4 p-4 pt-0">
      <div className="flex items-center justify-between gap-4">
        <div className="flex items-center gap-4">
          <Button variant="ghost" size="icon" onClick={() => router.back()}>
            <ArrowLeft className="h-4 w-4" />
          </Button>
          <div>
            <h2 className="text-2xl font-bold tracking-tight">{menu.Name}</h2>
            <p className="text-muted-foreground text-sm">
              {menu.Orientation || "Landscape"} • template: {menu.TemplateKey || "classic"}
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <Button variant="outline" size="icon" onClick={refresh} disabled={refreshing}>
            <RefreshCw className="h-4 w-4" />
          </Button>
          <Button variant="outline" onClick={handleCopyPublicUrl} disabled={!publicUrl}>
            <Copy className="mr-2 h-4 w-4" /> Copy public link
          </Button>
          <Button variant="outline" onClick={() => window.open(publicUrl, "_blank")} disabled={!publicUrl}>
            <ExternalLink className="mr-2 h-4 w-4" /> Preview
          </Button>
          <Button variant="outline" onClick={handleDuplicateMenu}>
            <Copy className="mr-2 h-4 w-4" /> Duplicate
          </Button>
          <Button onClick={handleSaveMenu} disabled={savingMenu}>
            <Save className="mr-2 h-4 w-4" /> {savingMenu ? "Saving..." : "Save"}
          </Button>
          <Button variant="destructive" onClick={handleDeleteMenu}>
            <Trash2 className="mr-2 h-4 w-4" /> Delete
          </Button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <Card className="lg:col-span-1">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Settings2 className="h-5 w-5" />
              Menu settings
            </CardTitle>
            <CardDescription>Basic properties and theme JSON.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid gap-2">
              <Label>Name</Label>
              <Input value={menu.Name} onChange={(e) => setMenu((p) => (p ? { ...p, Name: e.target.value } : p))} />
            </div>

            <div className="grid gap-2">
              <Label>Orientation</Label>
              <Select value={menu.Orientation || "Landscape"} onValueChange={(v) => setMenu((p) => (p ? { ...p, Orientation: v } : p))}>
                <SelectTrigger>
                  <SelectValue placeholder="Select orientation" />
                </SelectTrigger>
                <SelectContent position="popper" className="z-[10000]">
                  <SelectItem value="Landscape">Landscape</SelectItem>
                  <SelectItem value="Portrait">Portrait</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="grid gap-2">
              <Label>Template</Label>
              <Select value={menu.TemplateKey || "classic"} onValueChange={(v) => setMenu((p) => (p ? { ...p, TemplateKey: v } : p))}>
                <SelectTrigger>
                  <SelectValue placeholder="Select template" />
                </SelectTrigger>
                <SelectContent position="popper" className="z-[10000]">
                  <SelectItem value="classic">Classic</SelectItem>
                  <SelectItem value="minimal">Minimal</SelectItem>
                  <SelectItem value="neon">Neon</SelectItem>
                </SelectContent>
              </Select>
              <p className="text-xs text-muted-foreground">UI build: {APP_VERSION}</p>
            </div>

            <Separator />

            <div className="grid gap-3">
              <div className="flex items-center justify-between">
                <Label>Embedded preview</Label>
                <Switch checked={showEmbeddedPreview} onCheckedChange={setShowEmbeddedPreview} />
              </div>

              {showEmbeddedPreview ? (
                <div className="space-y-2">
                  <div className="flex flex-wrap gap-2">
                    <Button
                      type="button"
                      variant="outline"
                      size="sm"
                      onClick={() => setPreviewNonce((p) => p + 1)}
                      disabled={!publicUrl}
                    >
                      <RefreshCw className="mr-2 h-4 w-4" /> Reload preview
                    </Button>
                    <Button
                      type="button"
                      variant="outline"
                      size="sm"
                      onClick={() => window.open(publicUrl, "_blank")}
                      disabled={!publicUrl}
                    >
                      <ExternalLink className="mr-2 h-4 w-4" /> Open
                    </Button>
                  </div>

                  <div
                    className={
                      (menu.Orientation || "Landscape") === "Portrait"
                        ? "aspect-[9/16] w-full overflow-hidden rounded-md border bg-black"
                        : "aspect-video w-full overflow-hidden rounded-md border bg-black"
                    }
                  >
                    <iframe
                      key={previewNonce}
                      src={previewUrl}
                      className="h-full w-full"
                      allow="fullscreen"
                      referrerPolicy="no-referrer"
                      title="Menu preview"
                    />
                  </div>

                  <p className="text-xs text-muted-foreground">
                    Preview shows the last saved menu state.
                  </p>
                </div>
              ) : null}
            </div>

            <Separator />

            <div className="grid gap-4">
              <div>
                <div className="text-sm font-medium">Theme</div>
                <div className="text-xs text-muted-foreground">Quick controls (saved in ThemeConfig).</div>
              </div>

              {parsedTheme == null ? (
                <div className="rounded-md border border-amber-500/30 bg-amber-500/10 p-3">
                  <div className="text-sm font-medium">ThemeConfig JSON is invalid</div>
                  <div className="text-xs text-muted-foreground mt-1">
                    Fix the JSON at the bottom, or reset it. Theme controls (logo/background/section images) are disabled until it’s valid.
                  </div>
                  <div className="mt-3">
                    <Button type="button" variant="outline" onClick={resetThemeConfig}>
                      Reset ThemeConfig
                    </Button>
                  </div>
                </div>
              ) : null}

              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div className="grid gap-2">
                  <Label>Background</Label>
                  <div className="flex items-center gap-2">
                    <Input
                      type="color"
                      value={parsedTheme ? readThemeString(parsedTheme, "backgroundColor", "#0b0f19") : "#0b0f19"}
                      disabled={!parsedTheme}
                      onChange={(e) => updateThemeJson((t) => ({ ...t, backgroundColor: e.target.value }))}
                      className="h-10 w-14 p-1"
                    />
                    <Input
                      value={parsedTheme ? readThemeString(parsedTheme, "backgroundColor", "#0b0f19") : ""}
                      disabled={!parsedTheme}
                      onChange={(e) => updateThemeJson((t) => ({ ...t, backgroundColor: e.target.value }))}
                      placeholder="#0b0f19"
                    />
                  </div>
                </div>

                <div className="grid gap-2">
                  <Label>Text</Label>
                  <div className="flex items-center gap-2">
                    <Input
                      type="color"
                      value={parsedTheme ? readThemeString(parsedTheme, "textColor", "#ffffff") : "#ffffff"}
                      disabled={!parsedTheme}
                      onChange={(e) => updateThemeJson((t) => ({ ...t, textColor: e.target.value }))}
                      className="h-10 w-14 p-1"
                    />
                    <Input
                      value={parsedTheme ? readThemeString(parsedTheme, "textColor", "#ffffff") : ""}
                      disabled={!parsedTheme}
                      onChange={(e) => updateThemeJson((t) => ({ ...t, textColor: e.target.value }))}
                      placeholder="#ffffff"
                    />
                  </div>
                </div>

                <div className="grid gap-2">
                  <Label>Muted text</Label>
                  <div className="flex items-center gap-2">
                    <Input
                      type="color"
                      value={parsedTheme ? readThemeString(parsedTheme, "mutedTextColor", "#cbd5e1") : "#cbd5e1"}
                      disabled={!parsedTheme}
                      onChange={(e) => updateThemeJson((t) => ({ ...t, mutedTextColor: e.target.value }))}
                      className="h-10 w-14 p-1"
                    />
                    <Input
                      value={parsedTheme ? readThemeString(parsedTheme, "mutedTextColor", "#cbd5e1") : ""}
                      disabled={!parsedTheme}
                      onChange={(e) => updateThemeJson((t) => ({ ...t, mutedTextColor: e.target.value }))}
                      placeholder="#cbd5e1"
                    />
                  </div>
                </div>

                <div className="grid gap-2">
                  <Label>Accent</Label>
                  <div className="flex items-center gap-2">
                    <Input
                      type="color"
                      value={parsedTheme ? readThemeString(parsedTheme, "accentColor", "#22c55e") : "#22c55e"}
                      disabled={!parsedTheme}
                      onChange={(e) => updateThemeJson((t) => ({ ...t, accentColor: e.target.value }))}
                      className="h-10 w-14 p-1"
                    />
                    <Input
                      value={parsedTheme ? readThemeString(parsedTheme, "accentColor", "#22c55e") : ""}
                      disabled={!parsedTheme}
                      onChange={(e) => updateThemeJson((t) => ({ ...t, accentColor: e.target.value }))}
                      placeholder="#22c55e"
                    />
                  </div>
                </div>
              </div>

              <div className="grid gap-2">
                <Label>Layout columns</Label>
                <Select
                  value={parsedTheme ? readThemeColumns(parsedTheme) : "auto"}
                  onValueChange={(v) =>
                    updateThemeJson((t) => {
                      if (v === "auto") {
                        const copy = { ...t };
                        delete (copy as any).layoutColumns;
                        return copy;
                      }
                      return { ...t, layoutColumns: parseInt(v, 10) };
                    })
                  }
                  disabled={!parsedTheme}
                >
                  <SelectTrigger>
                    <SelectValue placeholder="Auto" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="auto">Auto (portrait=1, landscape=2)</SelectItem>
                    <SelectItem value="1">1 column</SelectItem>
                    <SelectItem value="2">2 columns</SelectItem>
                    <SelectItem value="3">3 columns</SelectItem>
                  </SelectContent>
                </Select>
                <div className="text-xs text-muted-foreground">
                  This controls how many section columns are rendered on the public menu display.
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div className="grid gap-2">
                  <Label>Background image</Label>
                  <div className="flex items-center gap-2">
                    <Input
                      value={parsedTheme ? readThemeString(parsedTheme, "backgroundImageUrl", "") : ""}
                      disabled={!parsedTheme}
                      onChange={(e) =>
                        updateThemeJson((t) => {
                          const next = { ...(t || {}) } as any;
                          const url = e.target.value.trim();
                          if (url) next.backgroundImageUrl = url;
                          else delete next.backgroundImageUrl;
                          return next as ThemeConfig;
                        })
                      }
                      placeholder="Optional"
                    />
                    <Button
                      type="button"
                      variant="outline"
                      size="icon"
                      onClick={() => openMediaPicker({ kind: "menuBackground" })}
                      aria-label="Pick background image from media library"
                      disabled={!parsedTheme}
                    >
                      <ImageIcon className="h-4 w-4" />
                    </Button>
                  </div>
                  {parsedTheme && readThemeString(parsedTheme, "backgroundImageUrl", "") ? (
                    <div className="mt-2">
                      <img
                        src={resolvePreviewSrc(readThemeString(parsedTheme, "backgroundImageUrl", ""))}
                        alt=""
                        className="h-20 w-28 rounded object-cover border"
                        loading="lazy"
                        onError={(e) => {
                          (e.currentTarget as HTMLImageElement).style.display = "none";
                        }}
                      />
                    </div>
                  ) : null}
                  <div className="text-xs text-muted-foreground">
                    Optional. Use the picker, or paste a direct URL.
                  </div>

                  <div className="grid gap-2 mt-2">
                    <Label>Background rotation (one URL per line)</Label>
                    <Textarea
                      value={
                        parsedTheme && Array.isArray((parsedTheme as any).backgroundImageUrls)
                          ? ((parsedTheme as any).backgroundImageUrls as unknown[])
                              .filter((x) => typeof x === "string")
                              .map((x) => (x as string).trim())
                              .filter(Boolean)
                              .join("\n")
                          : ""
                      }
                      disabled={!parsedTheme}
                      onChange={(e: ChangeEvent<HTMLTextAreaElement>) => {
                        const lines = (e.target.value || "")
                          .split("\n")
                          .map((x) => x.trim())
                          .filter(Boolean);

                        updateThemeJson((t) => {
                          const next = { ...(t || {}) } as any;
                          if (lines.length) next.backgroundImageUrls = lines;
                          else delete next.backgroundImageUrls;
                          return next as ThemeConfig;
                        });
                      }}
                      className="font-mono text-xs min-h-[110px]"
                      placeholder="https://...\nhttps://..."
                    />
                    <div className="text-xs text-muted-foreground">
                      When set, the public menu will randomly pick one image.
                    </div>
                  </div>
                </div>

                <div className="grid gap-2">
                  <Label>Logo</Label>
                  <div className="flex items-center gap-2">
                    <Input
                      value={parsedTheme ? readThemeString(parsedTheme, "logoUrl", "") : ""}
                      disabled={!parsedTheme}
                      onChange={(e) =>
                        updateThemeJson((t) => {
                          const next = { ...(t || {}) } as any;
                          const url = e.target.value.trim();
                          if (url) next.logoUrl = url;
                          else delete next.logoUrl;
                          return next as ThemeConfig;
                        })
                      }
                      placeholder="Optional"
                    />
                    <Button
                      type="button"
                      variant="outline"
                      size="icon"
                      onClick={() => openMediaPicker({ kind: "menuLogo" })}
                      aria-label="Pick logo from media library"
                      disabled={!parsedTheme}
                    >
                      <ImageIcon className="h-4 w-4" />
                    </Button>
                  </div>
                  {parsedTheme && readThemeString(parsedTheme, "logoUrl", "") ? (
                    <div className="mt-2">
                      <img
                        src={resolvePreviewSrc(readThemeString(parsedTheme, "logoUrl", ""))}
                        alt=""
                        className="h-12 w-20 rounded object-contain border bg-white/5"
                        loading="lazy"
                        onError={(e) => {
                          (e.currentTarget as HTMLImageElement).style.display = "none";
                        }}
                      />
                    </div>
                  ) : null}
                </div>
              </div>

              <div className="grid gap-2">
                <Label>Background overlay opacity</Label>
                <Input
                  type="number"
                  step="0.05"
                  min={0}
                  max={1}
                  value={
                    parsedTheme && typeof (parsedTheme as any).backgroundOverlayOpacity === "number"
                      ? String((parsedTheme as any).backgroundOverlayOpacity)
                      : "0.35"
                  }
                  disabled={!parsedTheme}
                  onChange={(e) => {
                    const n = parseFloat(e.target.value);
                    updateThemeJson((t) => ({ ...(t || {}), backgroundOverlayOpacity: isFinite(n) ? n : 0.35 }));
                  }}
                />
                <div className="text-xs text-muted-foreground">
                  Used when a background image is set.
                </div>
              </div>
            </div>

            <div className="grid gap-2">
              <Label>ThemeConfig (JSON)</Label>
              <Textarea value={themeJsonText} onChange={(e: ChangeEvent<HTMLTextAreaElement>) => setThemeJsonText(e.target.value)} className="font-mono text-xs min-h-[220px]" />
              <p className="text-xs text-muted-foreground">Example keys: backgroundColor, textColor, accentColor.</p>
            </div>
          </CardContent>
        </Card>

        <Card className="lg:col-span-2">
          <CardHeader className="flex flex-row items-start justify-between gap-4">
            <div>
              <CardTitle>Sections</CardTitle>
              <CardDescription>Build your menu structure: sections and items.</CardDescription>
            </div>
            <div className="flex flex-wrap items-center gap-2">
              <Dialog open={isImportCsvOpen} onOpenChange={setIsImportCsvOpen}>
                <DialogTrigger asChild>
                  <Button variant="outline">
                    Import CSV
                  </Button>
                </DialogTrigger>
                <DialogContent className="max-w-3xl">
                  <DialogHeader>
                    <DialogTitle>Import items from CSV</DialogTitle>
                    <DialogDescription>
                      CSV must have a header row. Required columns: <span className="font-mono">Section</span> and <span className="font-mono">Name</span>.
                      Optional: <span className="font-mono">Sku</span>, <span className="font-mono">Description</span>, <span className="font-mono">ImageUrl</span>, <span className="font-mono">Price</span> (ZAR), <span className="font-mono">PriceCents</span>, <span className="font-mono">IsAvailable</span>, <span className="font-mono">DisplayOrder</span>.
                    </DialogDescription>
                  </DialogHeader>

                  <div className="grid gap-3 py-2">
                    <div className="grid gap-2">
                      <Label>CSV file (optional)</Label>
                      <Input
                        type="file"
                        accept=".csv,text/csv"
                        onChange={(e) => {
                          const file = e.target.files?.[0];
                          if (!file) return;
                          const reader = new FileReader();
                          reader.onload = () => {
                            setCsvText(String(reader.result || ""));
                            setCsvDryRun(null);
                          };
                          reader.readAsText(file);
                        }}
                      />
                    </div>

                    <div className="grid gap-2">
                      <Label>CSV text</Label>
                      <Textarea
                        value={csvText}
                        onChange={(e: ChangeEvent<HTMLTextAreaElement>) => {
                          setCsvText(e.target.value);
                          setCsvDryRun(null);
                        }}
                        className="font-mono text-xs min-h-[240px]"
                        placeholder="Section,Name,Sku,Description,Price\nBurgers,Cheese Burger,POS-123,200g beef,89.99"
                      />
                      <div className="text-xs text-muted-foreground">
                        Rows with unknown sections will create new sections automatically.
                      </div>

                      {csvDryRun ? (
                        <div className="rounded-md border p-3 text-sm">
                          <div className="flex flex-wrap gap-x-4 gap-y-1">
                            <div><span className="font-semibold">Rows:</span> {csvDryRun.totalRows}</div>
                            <div><span className="font-semibold">Ready:</span> {csvDryRun.okRows}</div>
                            <div><span className="font-semibold">Errors:</span> {csvDryRun.errorRows}</div>
                            <div><span className="font-semibold">New sections:</span> {csvDryRun.newSections.length}</div>
                          </div>

                          {csvDryRun.newSections.length > 0 ? (
                            <div className="mt-2 text-xs text-muted-foreground">
                              Will create sections: {csvDryRun.newSections.slice(0, 8).join(", ")}{csvDryRun.newSections.length > 8 ? "…" : ""}
                            </div>
                          ) : null}

                          {csvDryRun.errorRows > 0 ? (
                            <div className="mt-2 text-xs text-red-600">
                              First errors: {csvDryRun.plan.filter((r) => r.status === "error").slice(0, 3).map((r) => `#${r.rowNumber} ${r.message || "Error"}`).join(" • ")}
                            </div>
                          ) : null}

                          <div className="mt-3">
                            <div className="text-xs font-semibold mb-2">Preview (first 10)</div>
                            <div className="max-h-[220px] overflow-auto rounded border">
                              <Table>
                                <TableHeader>
                                  <TableRow>
                                    <TableHead className="w-[70px]">Row</TableHead>
                                    <TableHead>Section</TableHead>
                                    <TableHead>Name</TableHead>
                                    <TableHead className="w-[140px]">SKU</TableHead>
                                    <TableHead className="w-[140px]">Price</TableHead>
                                    <TableHead className="w-[120px]">Creates section</TableHead>
                                    <TableHead className="w-[100px]">Status</TableHead>
                                  </TableRow>
                                </TableHeader>
                                <TableBody>
                                  {csvDryRun.plan.slice(0, 10).map((r) => (
                                    <TableRow key={r.rowNumber}>
                                      <TableCell className="font-mono text-xs">{r.rowNumber}</TableCell>
                                      <TableCell>{r.sectionName}</TableCell>
                                      <TableCell>{r.name}</TableCell>
                                      <TableCell className="font-mono text-xs">{r.sku}</TableCell>
                                      <TableCell>{r.priceCents == null ? "" : formatCurrencyZarFromCents(r.priceCents)}</TableCell>
                                      <TableCell>{r.willCreateSection ? "Yes" : "No"}</TableCell>
                                      <TableCell>
                                        <span className={r.status === "ok" ? "text-green-700" : "text-red-600"}>
                                          {r.status.toUpperCase()}
                                        </span>
                                      </TableCell>
                                    </TableRow>
                                  ))}
                                </TableBody>
                              </Table>
                            </div>
                          </div>
                        </div>
                      ) : null}
                    </div>
                  </div>

                  <DialogFooter>
                    <Button variant="outline" onClick={() => { setCsvText(""); setCsvDryRun(null); }} disabled={importingCsv || dryRunningCsv}>
                      Clear
                    </Button>
                    <Button variant="outline" onClick={handleDryRunCsv} disabled={dryRunningCsv || importingCsv || !csvText.trim()}>
                      {dryRunningCsv ? "Running..." : "Dry run"}
                    </Button>
                    <Button onClick={handleImportCsv} disabled={importingCsv || dryRunningCsv || !csvText.trim() || !csvDryRun || csvDryRun.sourceText !== csvText || csvDryRun.okRows === 0}>
                      {importingCsv ? "Importing..." : "Import"}
                    </Button>
                  </DialogFooter>
                </DialogContent>
              </Dialog>

              <Dialog open={isAddSectionOpen} onOpenChange={setIsAddSectionOpen}>
                <DialogTrigger asChild>
                  <Button>
                    <Plus className="mr-2 h-4 w-4" /> Add section
                  </Button>
                </DialogTrigger>
                <DialogContent>
                  <DialogHeader>
                    <DialogTitle>Add section</DialogTitle>
                    <DialogDescription>Sections group items on your menu board.</DialogDescription>
                  </DialogHeader>
                  <div className="grid gap-4 py-4">
                    <div className="grid gap-2">
                      <Label>Name</Label>
                      <Input value={newSection.name} onChange={(e) => setNewSection((p) => ({ ...p, name: e.target.value }))} placeholder="e.g. Burgers" />
                    </div>
                    <div className="grid gap-2">
                      <Label>Display order</Label>
                      <Input
                        type="number"
                        value={newSection.displayOrder}
                        onChange={(e) => setNewSection((p) => ({ ...p, displayOrder: parseInt(e.target.value) || 0 }))}
                        placeholder="Auto"
                      />
                    </div>
                  </div>
                  <DialogFooter>
                    <Button onClick={handleCreateSection}>Create</Button>
                  </DialogFooter>
                </DialogContent>
              </Dialog>
            </div>
          </CardHeader>

          <CardContent>
            {sections.length === 0 ? (
              <div className="py-10 text-center text-muted-foreground">No sections yet. Add one to start.</div>
            ) : (
              <div className="space-y-6">
                {sections
                  .slice()
                  .sort((a, b) => a.DisplayOrder - b.DisplayOrder)
                  .map((s) => {
                    const sectionItems = (itemsBySection[s.Id] || []).slice().sort((a, b) => a.DisplayOrder - b.DisplayOrder);
                    const sectionImageUrl =
                      parsedTheme && typeof (parsedTheme as any).sectionImages === "object" && (parsedTheme as any).sectionImages
                        ? String(((parsedTheme as any).sectionImages as any)[String(s.Id)] || "")
                        : "";
                    return (
                      <Card key={s.Id} className="border-dashed">
                        <CardHeader className="pb-2">
                          <div className="flex flex-col md:flex-row md:items-end md:justify-between gap-3">
                            <div className="flex-1 grid grid-cols-1 md:grid-cols-3 gap-3">
                              <div className="grid gap-2 md:col-span-2">
                                <Label>Section name</Label>
                                <Input
                                  value={s.Name}
                                  onChange={(e) =>
                                    setSections((prev) => prev.map((x) => (x.Id === s.Id ? { ...x, Name: e.target.value } : x)))
                                  }
                                  onBlur={() => {
                                    const latest = sections.find((x) => x.Id === s.Id) || s;
                                    handleUpdateSection(latest);
                                  }}
                                />
                              </div>
                              <div className="grid gap-2">
                                <Label>Order</Label>
                                <Input
                                  type="number"
                                  value={s.DisplayOrder}
                                  onChange={(e) =>
                                    setSections((prev) =>
                                      prev.map((x) => (x.Id === s.Id ? { ...x, DisplayOrder: parseInt(e.target.value) || 0 } : x))
                                    )
                                  }
                                  onBlur={() => {
                                    const latest = sections.find((x) => x.Id === s.Id) || s;
                                    handleUpdateSection(latest);
                                  }}
                                />
                              </div>
                            </div>
                            <div className="flex items-center gap-2">
                              <Button variant="outline" onClick={() => openAddItem(s.Id)}>
                                <Plus className="mr-2 h-4 w-4" /> Add item
                              </Button>
                              <Button variant="destructive" onClick={() => handleDeleteSection(s.Id)}>
                                <Trash2 className="mr-2 h-4 w-4" /> Delete
                              </Button>
                            </div>
                          </div>

                          <div className="mt-3 grid gap-2">
                            <Label>Section image (optional)</Label>
                            <div className="flex items-center gap-2">
                              <Input
                                value={sectionImageUrl}
                                onChange={(e) => {
                                  const url = e.target.value.trim();
                                  updateThemeJson((theme) => {
                                    const next = { ...(theme || {}) } as any;
                                    const current = next.sectionImages;
                                    const map: Record<string, string> =
                                      current && typeof current === "object" && !Array.isArray(current)
                                        ? { ...(current as Record<string, string>) }
                                        : {};
                                    if (url) map[String(s.Id)] = url;
                                    else delete map[String(s.Id)];
                                    if (Object.keys(map).length === 0) delete next.sectionImages;
                                    else next.sectionImages = map;
                                    return next as ThemeConfig;
                                  });
                                }}
                                placeholder="Optional"
                                disabled={!parsedTheme}
                              />
                              <Button
                                type="button"
                                variant="outline"
                                size="icon"
                                onClick={() => openMediaPicker({ kind: "sectionImage", sectionId: s.Id })}
                                aria-label="Pick section image from media library"
                                disabled={!parsedTheme}
                              >
                                <ImageIcon className="h-4 w-4" />
                              </Button>
                            </div>
                            {sectionImageUrl ? (
                              <div className="mt-1 flex items-center gap-2">
                                <img
                                  src={resolvePreviewSrc(sectionImageUrl)}
                                  alt=""
                                  className="h-12 w-20 rounded object-cover border"
                                  loading="lazy"
                                  onError={(e) => {
                                    (e.currentTarget as HTMLImageElement).style.display = "none";
                                  }}
                                />
                                <span className="text-[11px] text-muted-foreground truncate">Preview</span>
                              </div>
                            ) : null}
                          </div>
                        </CardHeader>
                        <CardContent>
                          {sectionItems.length === 0 ? (
                            <div className="py-6 text-center text-muted-foreground">No items in this section yet.</div>
                          ) : (
                            <Table>
                              <TableHeader>
                                <TableRow>
                                  <TableHead>Name</TableHead>
                                  <TableHead className="w-[160px]">SKU</TableHead>
                                  <TableHead>Description</TableHead>
                                  <TableHead className="w-[260px]">Image URL</TableHead>
                                  <TableHead className="w-[140px]">Price</TableHead>
                                  <TableHead className="w-[120px]">Available</TableHead>
                                  <TableHead className="w-[120px]">Order</TableHead>
                                  <TableHead className="w-[70px]"></TableHead>
                                </TableRow>
                              </TableHeader>
                              <TableBody>
                                {sectionItems.map((it) => (
                                  <TableRow key={it.Id}>
                                    <TableCell>
                                      <Input
                                        value={it.Name}
                                        onChange={(e) =>
                                          setItemsBySection((prev) => ({
                                            ...prev,
                                            [s.Id]: (prev[s.Id] || []).map((x) => (x.Id === it.Id ? { ...x, Name: e.target.value } : x)),
                                          }))
                                        }
                                        onBlur={() => {
                                          const latest = (itemsBySection[s.Id] || []).find((x) => x.Id === it.Id) || it;
                                          handleUpdateItem(latest);
                                        }}
                                      />
                                    </TableCell>
                                    <TableCell>
                                      <Input
                                        value={it.Sku ?? ""}
                                        onChange={(e) =>
                                          setItemsBySection((prev) => ({
                                            ...prev,
                                            [s.Id]: (prev[s.Id] || []).map((x) => (x.Id === it.Id ? { ...x, Sku: e.target.value || null } : x)),
                                          }))
                                        }
                                        onBlur={() => {
                                          const latest = (itemsBySection[s.Id] || []).find((x) => x.Id === it.Id) || it;
                                          handleUpdateItem(latest);
                                        }}
                                        placeholder="Optional"
                                      />
                                    </TableCell>
                                    <TableCell>
                                      <Input
                                        value={it.Description ?? ""}
                                        onChange={(e) =>
                                          setItemsBySection((prev) => ({
                                            ...prev,
                                            [s.Id]: (prev[s.Id] || []).map((x) => (x.Id === it.Id ? { ...x, Description: e.target.value || null } : x)),
                                          }))
                                        }
                                        onBlur={() => {
                                          const latest = (itemsBySection[s.Id] || []).find((x) => x.Id === it.Id) || it;
                                          handleUpdateItem(latest);
                                        }}
                                        placeholder="Optional"
                                      />
                                    </TableCell>
                                    <TableCell>
                                      <div className="flex items-center gap-2">
                                        <Input
                                          value={it.ImageUrl ?? ""}
                                          onChange={(e) =>
                                            setItemsBySection((prev) => ({
                                              ...prev,
                                              [s.Id]: (prev[s.Id] || []).map((x) => (x.Id === it.Id ? { ...x, ImageUrl: e.target.value || null } : x)),
                                            }))
                                          }
                                          onBlur={() => {
                                            const latest = (itemsBySection[s.Id] || []).find((x) => x.Id === it.Id) || it;
                                            handleUpdateItem(latest);
                                          }}
                                          placeholder="Optional"
                                        />
                                        <Button
                                          type="button"
                                          variant="outline"
                                          size="icon"
                                          onClick={() => openMediaPicker({ kind: "existing", sectionId: s.Id, itemId: it.Id })}
                                          aria-label="Pick image from media library"
                                        >
                                          <ImageIcon className="h-4 w-4" />
                                        </Button>
                                      </div>
                                      {it.ImageUrl ? (
                                        <div className="mt-2 flex items-center gap-2">
                                          <img
                                            src={resolvePreviewSrc(it.ImageUrl)}
                                            alt=""
                                            className="h-10 w-10 rounded object-cover border"
                                            onError={(e) => {
                                              (e.currentTarget as HTMLImageElement).style.display = "none";
                                            }}
                                          />
                                          <span className="text-[11px] text-muted-foreground truncate">Preview</span>
                                        </div>
                                      ) : null}
                                    </TableCell>
                                    <TableCell>
                                      <Input
                                        value={it.PriceCents != null ? (it.PriceCents / 100).toFixed(2) : ""}
                                        onChange={(e) => {
                                          const txt = e.target.value;
                                          const cents = txt.trim() === "" ? null : Math.round(parseFloat(txt) * 100);
                                          setItemsBySection((prev) => ({
                                            ...prev,
                                            [s.Id]: (prev[s.Id] || []).map((x) => (x.Id === it.Id ? { ...x, PriceCents: isFinite(Number(cents)) ? cents : x.PriceCents } : x)),
                                          }));
                                        }}
                                        onBlur={() => {
                                          const latest = (itemsBySection[s.Id] || []).find((x) => x.Id === it.Id) || it;
                                          handleUpdateItem(latest);
                                        }}
                                        placeholder="e.g. 49.99"
                                      />
                                      {it.PriceCents != null && (
                                        <div className="text-[11px] text-muted-foreground mt-1">
                                          {formatCurrencyZarFromCents(it.PriceCents)}
                                        </div>
                                      )}
                                    </TableCell>
                                    <TableCell>
                                      <div className="flex items-center gap-2">
                                        <Switch
                                          checked={it.IsAvailable}
                                          onCheckedChange={(checked) => {
                                            setItemsBySection((prev) => ({
                                              ...prev,
                                              [s.Id]: (prev[s.Id] || []).map((x) => (x.Id === it.Id ? { ...x, IsAvailable: checked } : x)),
                                            }));
                                            handleUpdateItem({ ...it, IsAvailable: checked });
                                          }}
                                        />
                                      </div>
                                    </TableCell>
                                    <TableCell>
                                      <Input
                                        type="number"
                                        value={it.DisplayOrder}
                                        onChange={(e) =>
                                          setItemsBySection((prev) => ({
                                            ...prev,
                                            [s.Id]: (prev[s.Id] || []).map((x) => (x.Id === it.Id ? { ...x, DisplayOrder: parseInt(e.target.value) || 0 } : x)),
                                          }))
                                        }
                                        onBlur={() => {
                                          const latest = (itemsBySection[s.Id] || []).find((x) => x.Id === it.Id) || it;
                                          handleUpdateItem(latest);
                                        }}
                                      />
                                    </TableCell>
                                    <TableCell>
                                      <Button variant="ghost" size="icon" onClick={() => handleDeleteItem(it)}>
                                        <Trash2 className="h-4 w-4" />
                                      </Button>
                                    </TableCell>
                                  </TableRow>
                                ))}
                              </TableBody>
                            </Table>
                          )}
                        </CardContent>
                      </Card>
                    );
                  })}
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      <Dialog open={addItemSectionId != null} onOpenChange={(open) => !open && setAddItemSectionId(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Add item</DialogTitle>
            <DialogDescription>Add an item to this section.</DialogDescription>
          </DialogHeader>
          <div className="grid gap-4 py-4">
            <div className="grid gap-2">
              <Label>Name</Label>
              <Input value={newItem.name} onChange={(e) => setNewItem((p) => ({ ...p, name: e.target.value }))} />
            </div>
            <div className="grid gap-2">
              <Label>SKU</Label>
              <Input value={newItem.sku} onChange={(e) => setNewItem((p) => ({ ...p, sku: e.target.value }))} placeholder="Optional" />
            </div>
            <div className="grid gap-2">
              <Label>Description</Label>
              <Input value={newItem.description} onChange={(e) => setNewItem((p) => ({ ...p, description: e.target.value }))} placeholder="Optional" />
            </div>
            <div className="grid gap-2">
              <Label>Image URL</Label>
              <div className="flex items-center gap-2">
                <Input value={newItem.imageUrl} onChange={(e) => setNewItem((p) => ({ ...p, imageUrl: e.target.value }))} placeholder="Optional" />
                <Button
                  type="button"
                  variant="outline"
                  size="icon"
                  onClick={() => openMediaPicker({ kind: "new" })}
                  aria-label="Pick image from media library"
                >
                  <ImageIcon className="h-4 w-4" />
                </Button>
              </div>
              <div className="text-xs text-muted-foreground">Upload an image or select one from Media Library.</div>
              {resolvePreviewSrc(newItem.imageUrl) ? (
                <div className="mt-2">
                  <img
                    src={resolvePreviewSrc(newItem.imageUrl)}
                    alt=""
                    className="h-16 w-16 rounded object-cover border"
                    onError={(e) => {
                      (e.currentTarget as HTMLImageElement).style.display = "none";
                    }}
                  />
                </div>
              ) : null}
            </div>
            <div className="grid gap-2">
              <Label>Price (ZAR)</Label>
              <Input value={newItem.price} onChange={(e) => setNewItem((p) => ({ ...p, price: e.target.value }))} placeholder="Optional, e.g. 49.99" />
            </div>
            <div className="flex items-center justify-between">
              <div className="grid gap-1">
                <Label>Available</Label>
                <span className="text-xs text-muted-foreground">Hide/unavailable items on the board.</span>
              </div>
              <Switch checked={newItem.isAvailable} onCheckedChange={(v) => setNewItem((p) => ({ ...p, isAvailable: v }))} />
            </div>
            <div className="grid gap-2">
              <Label>Order</Label>
              <Input type="number" value={newItem.displayOrder} onChange={(e) => setNewItem((p) => ({ ...p, displayOrder: parseInt(e.target.value) || 0 }))} />
            </div>
          </div>
          <DialogFooter>
            <Button onClick={handleCreateItem}>Create</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog
        open={isMediaPickerOpen}
        onOpenChange={(open) => {
          setIsMediaPickerOpen(open);
          if (!open) {
            setMediaQuery("");
            setMediaPickerTarget(null);
          }
        }}
      >
        <DialogContent className="max-w-3xl">
          <DialogHeader>
            <DialogTitle>Choose an image</DialogTitle>
            <DialogDescription>
              Select an existing image from Media Library, or upload a new one.
            </DialogDescription>
          </DialogHeader>

          <div className="grid gap-3">
            <div className="flex flex-wrap items-center gap-2">
              <Button type="button" variant="outline" size="icon" onClick={fetchMediaLibrary} aria-label="Refresh media">
                <RefreshCw className="h-4 w-4" />
              </Button>
              <Input
                value={mediaQuery}
                onChange={(e) => setMediaQuery(e.target.value)}
                placeholder="Search images…"
                className="max-w-sm"
              />
              <div className="ml-auto flex items-center gap-2">
                <Input ref={uploadFileRef} type="file" accept="image/*" className="max-w-xs" />
                <Button type="button" onClick={uploadImageAndSelect} disabled={uploadingImage}>
                  <Upload className="mr-2 h-4 w-4" />
                  {uploadingImage ? "Uploading…" : "Upload"}
                </Button>
              </div>
            </div>

            {mediaLoading ? (
              <div className="text-sm text-muted-foreground">Loading media…</div>
            ) : (
              <div className="max-h-[460px] overflow-auto rounded-md border p-3">
                {mediaLibrary
                  .filter((m) => (m.FileType || "").startsWith("image/"))
                  .filter((m) => {
                    const q = mediaQuery.trim().toLowerCase();
                    if (!q) return true;
                    return (m.FileName || "").toLowerCase().includes(q);
                  })
                  .slice(0, 1).length === 0 ? (
                  <div className="py-8 text-center text-sm text-muted-foreground">No images found.</div>
                ) : (
                  <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
                    {mediaLibrary
                      .filter((m) => (m.FileType || "").startsWith("image/"))
                      .filter((m) => {
                        const q = mediaQuery.trim().toLowerCase();
                        if (!q) return true;
                        return (m.FileName || "").toLowerCase().includes(q);
                      })
                      .slice(0, 200)
                      .map((m) => (
                        <button
                          key={m.Id}
                          type="button"
                          className="group rounded-md border bg-background hover:bg-accent/10 text-left overflow-hidden"
                          onClick={async () => {
                            await applyImageUrlToTarget(makeMediaRef(m.Id));
                            void ensureMediaPreviewUrl(m.Id);
                            setIsMediaPickerOpen(false);
                          }}
                        >
                          <div className="aspect-square bg-black/20">
                            {mediaPreviewUrls[m.Id] ? (
                              <img
                                src={mediaPreviewUrls[m.Id]}
                                alt={m.FileName}
                                className="h-full w-full object-cover"
                                loading="lazy"
                                onError={(e) => {
                                  (e.currentTarget as HTMLImageElement).style.display = "none";
                                }}
                              />
                            ) : (
                              <div className="h-full w-full flex items-center justify-center text-xs text-muted-foreground">
                                Preview loading…
                              </div>
                            )}
                          </div>
                          <div className="p-2">
                            <div className="text-xs font-medium truncate" title={m.FileName}>
                              {m.FileName}
                            </div>
                            <div className="text-[11px] text-muted-foreground truncate">
                              {m.Orientation}
                            </div>
                          </div>
                        </button>
                      ))}
                  </div>
                )}
              </div>
            )}
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}
