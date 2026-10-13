import { spawn } from "node:child_process";
import { access, mkdir, stat } from "node:fs/promises";
import path from "node:path";
import { chromium } from "playwright-core";
// PARCHE (2026-10-12): Flow se mudó de labs.google/fx/tools/flow a flow.google.com y cambió su interfaz.
const FLOW_URL = "https://flow.google.com/";
const FLOW_HOSTS = ["flow.google.com"];
const CREDIT_ACTION = /^(generate|create|generar|crear|iniciar generación|arrow_forward|生成|制作|产生)(\s|$)/i;
const BLOCKED_AUTH_ACTION = /(password|passkey|verification|contraseña|verificación|cerrar sesión|cuenta de google|sign\s*out|log\s*out|退出登录|登出)/i;
export class FlowBrowserAdapter {
    config;
    store;
    context;
    page;
    constructor(config, store) {
        this.config = config;
        this.store = store;
    }
    async startLogin(projectId) {
        const state = await this.store.read();
        if (!state.projects.some((project) => project.id === projectId))
            throw new Error(`Project not found: ${projectId}`);
        await this.close();
        const loginBrowser = spawn(this.config.browserExecutable, [
            `--user-data-dir=${this.config.profileDir}`,
            "--no-first-run",
            "--no-default-browser-check",
            "--start-maximized",
            FLOW_URL,
        ], { detached: true, stdio: "ignore", windowsHide: false });
        loginBrowser.unref();
        const next = await this.store.update((draft) => {
            draft.auth = {
                status: "awaiting_user_fresh_sign_in",
                initiatedAt: new Date().toISOString(),
                lastUrl: FLOW_URL,
                lastMessage: "Inicia sesión tú en la ventana de Chrome que se ha abierto. Cuando estés dentro de Flow, cierra todas las ventanas de ese Chrome y avisa a Claude. Nunca le pases contraseñas ni códigos.",
            };
        });
        return next.auth;
    }
    async getAuthStatus() {
        if (!this.context || !this.page || this.page.isClosed())
            return (await this.store.read()).auth;
        const detected = await this.detectAuthentication();
        const state = await this.store.read();
        const status = detected === "login_required" ? "login_required" : state.auth.status === "ready" ? "ready" : "signed_in_unconfirmed";
        const next = await this.store.update((draft) => {
            draft.auth.status = status;
            draft.auth.lastUrl = this.page.url();
            draft.auth.lastMessage = status === "login_required"
                ? "请在可见浏览器中完成 Google 登录。"
                : status === "ready" ? "登录检查点已完成。" : "浏览器已登录；仍需用户确认全新登录、会员资格和可用额度。";
        });
        return next.auth;
    }
    async confirmLogin(input) {
        if (!input.userConfirmedFreshSignIn)
            throw new Error("Fresh sign-in must be completed and confirmed by the user.");
        if (!input.membershipConfirmed || !input.creditsAvailableConfirmed) {
            throw new Error("Google Flow membership/access and usable credits must be confirmed before generation.");
        }
        const state = await this.store.read();
        if (!state.projects.some((project) => project.id === input.projectId))
            throw new Error(`Project not found: ${input.projectId}`);
        try {
            const page = await this.ensurePage();
            if (!page.url().startsWith(FLOW_URL))
                await page.goto(FLOW_URL, { waitUntil: "domcontentloaded", timeout: 45_000 });
            if ((await this.detectAuthentication()) === "login_required")
                throw new Error("Google still shows a login page. Complete login in the normal Chrome window first.");
        }
        catch (error) {
            if (/profile.*in use|processsingleton|user data directory.*in use|singletonlock/i.test(error.message)) {
                throw new Error("The login Chrome is still running. Close all windows using the dedicated Flow profile, then confirm login again.", { cause: error });
            }
            throw error;
        }
        const next = await this.store.update((draft) => {
            draft.auth.status = "ready";
            draft.auth.confirmedAt = new Date().toISOString();
            draft.auth.freshLoginForProjectId = input.projectId;
            draft.auth.lastUrl = this.page?.url();
            draft.auth.lastMessage = "Fresh login, membership/access, and usable credits were user-confirmed.";
        });
        return next.auth;
    }
    async inspectPage() {
        const page = await this.ensurePage();
        const buttons = await this.visibleControls("button, [role='button'], a[href], [tabindex]:not([tabindex='-1']), summary, input[type='button'], input[type='submit']");
        const textboxes = await this.visibleControls("textarea, input[type='text'], input:not([type]), [contenteditable='true'], [role='textbox']");
        let fileInputCount = 0;
        for (const frame of page.frames())
            fileInputCount += await frame.locator("input[type='file']").count();
        const bodyText = await page.locator("body").innerText().catch(() => "");
        return {
            url: page.url(),
            title: await page.title(),
            visibleText: bodyText.replace(/\s+/g, " ").trim().slice(0, 12_000),
            buttons: buttons.slice(0, 120).map((control, index) => ({ index, label: control.label, frame: control.frame })),
            textboxes: await Promise.all(textboxes.slice(0, 40).map(async (control, index) => ({
                index,
                label: control.label,
                multiline: await control.locator.evaluate((element) => element.tagName === "TEXTAREA" || element.getAttribute("aria-multiline") === "true"),
                frame: control.frame,
            }))),
            fileInputCount,
            media: await this.inspectMedia(),
            failureCount: (bodyText.match(/\bwarning\s+Failed\b|No se ha podido generar|Error al generar|生成失败/gi) ?? []).length,
        };
    }
    async openFlowProject(projectUrl) {
        this.validateFlowProjectUrl(projectUrl);
        const page = await this.ensurePage();
        await page.goto(projectUrl, { waitUntil: "domcontentloaded", timeout: 45_000 });
        await page.waitForTimeout(3_000);
        return this.inspectPage();
    }
    async openMedia(input) {
        await this.openFlowProject(input.projectUrl);
        const media = await this.findMedia(input);
        const page = await this.ensurePage();
        await page.locator(`[data-media-id="${media.tileId}"]`).first().click();
        await page.waitForURL(/\/edit\//, { timeout: 30_000 });
        media.href = page.url();
        await page.getByRole("button", { name: /Descargar|Download|下载/i }).first().waitFor({ state: "visible", timeout: 30_000 });
        await page.waitForTimeout(500);
        return { media, page: await this.inspectPage() };
    }
    async waitForMedia(input) {
        const page = await this.ensurePage();
        if (!page.url().startsWith(input.projectUrl))
            await this.openFlowProject(input.projectUrl);
        const baseline = new Set(input.baselineMediaIds);
        const deadline = Date.now() + input.timeoutSeconds * 1_000;
        let failedObservations = 0;
        let observations = 0;
        let inspection = await this.inspectPage();
        while (Date.now() <= deadline) {
            observations += 1;
            inspection = await this.inspectPage();
            const created = inspection.media.find((item) => item.kind === input.expectedKind && !baseline.has(item.tileId) && (!item.providerMediaId || !baseline.has(item.providerMediaId)));
            if (created)
                return { status: "complete", media: created, observations, page: inspection };
            failedObservations = inspection.failureCount > input.baselineFailureCount ? failedObservations + 1 : 0;
            if (failedObservations >= 3)
                return { status: "failed", observations, page: inspection };
            const remaining = deadline - Date.now();
            if (remaining <= 0)
                break;
            await page.waitForTimeout(Math.min(input.pollIntervalSeconds * 1_000, remaining));
            await page.reload({ waitUntil: "domcontentloaded", timeout: 45_000 }).catch(() => undefined);
            await page.waitForTimeout(1_500);
        }
        return { status: "timeout", observations, page: inspection };
    }
    async fillTextbox(input) {
        const page = await this.ensurePage();
        if (new URL(page.url()).hostname === "accounts.google.com")
            throw new Error("Credential entry is user-only. Type login details directly in the visible browser.");
        const controls = await this.visibleControls("textarea, input[type='text'], input:not([type]), [contenteditable='true'], [role='textbox']");
        const target = this.chooseControl(controls, input.label, input.index, "textbox");
        if (BLOCKED_AUTH_ACTION.test(target.label))
            throw new Error("MCP refuses to fill credential or verification fields.");
        await target.locator.fill(input.text);
        return this.inspectPage();
    }
    async uploadFile(input) {
        const page = await this.ensurePage();
        const absolute = path.resolve(input.filePath);
        await access(absolute);
        const inputs = [];
        for (const frame of page.frames()) {
            const locator = frame.locator("input[type='file']");
            for (let index = 0; index < await locator.count(); index += 1)
                inputs.push(locator.nth(index));
        }
        if (inputs.length === 0)
            throw new Error("No file input is currently present. Inspect or open the upload control first.");
        const index = input.inputIndex ?? 0;
        if (!inputs[index])
            throw new Error(`File input index ${index} does not exist.`);
        await inputs[index].setInputFiles(absolute);
        return this.inspectPage();
    }
    async bindAssetToPrompt(input) {
        const sources = await this.visibleControls("button, [role='button'], a[href], [tabindex]:not([tabindex='-1'])");
        let source;
        try {
            source = this.chooseControl(sources, input.assetLabel, undefined, "asset");
        }
        catch (error) {
            const textMatches = await this.visibleExactText(input.assetLabel);
            if (textMatches.length !== 1)
                throw error;
            source = textMatches[0];
        }
        const prompts = await this.visibleControls("textarea, input[type='text'], input:not([type]), [contenteditable='true'], [role='textbox']");
        const prompt = this.chooseControl(prompts, input.promptLabel, undefined, "prompt textbox");
        await source.locator.dragTo(prompt.locator, { timeout: 30_000 });
        await this.page?.waitForTimeout(1_500);
        return this.inspectPage();
    }
    async clickControl(input) {
        const controls = await this.visibleControls("button, [role='button'], a[href], [tabindex]:not([tabindex='-1']), summary, input[type='button'], input[type='submit']");
        let target;
        try {
            target = this.chooseControl(controls, input.label, input.index, "button");
        }
        catch (error) {
            if (!input.label || input.index !== undefined)
                throw error;
            const textMatches = await this.visibleExactText(input.label);
            if (textMatches.length !== 1)
                throw error;
            target = textMatches[0];
        }
        if (BLOCKED_AUTH_ACTION.test(target.label))
            throw new Error("Signing out and credential-related actions are user-only.");
        if (CREDIT_ACTION.test(target.label) && !input.allowCreditSpend)
            throw new Error("This control may spend Google Flow credits. Set allowCreditSpend=true only after user approval.");
        await target.locator.click();
        await this.page?.waitForLoadState("domcontentloaded", { timeout: 10_000 }).catch(() => undefined);
        try {
            return await this.inspectPage();
        }
        catch {
            const page = await this.ensurePage();
            return { url: page.url(), title: await page.title().catch(() => ""), visibleText: "", buttons: [], textboxes: [], fileInputCount: 0, media: [], failureCount: 0 };
        }
    }
    async downloadAsset(input) {
        const page = await this.ensurePage();
        const controls = await this.visibleControls("button, [role='button'], a[href], [tabindex]:not([tabindex='-1']), summary, input[type='button'], input[type='submit']");
        let target;
        try {
            target = this.chooseControl(controls, input.label, input.index, "download control");
        }
        catch (error) {
            if (!input.label || input.index !== undefined)
                throw error;
            const textMatches = await this.visibleExactText(input.label);
            if (textMatches.length !== 1)
                throw error;
            target = textMatches[0];
        }
        const downloadPromise = page.waitForEvent("download", { timeout: 30_000 });
        await target.locator.click();
        const download = await downloadPromise;
        return this.saveDownload(download, input.destinationDir, input.fileName, page.url());
    }
    async downloadMedia(input) {
        const { media } = await this.openMedia(input);
        const page = await this.ensurePage();
        const downloadControl = page.getByRole("button", { name: /Descargar|Download|下载/i }).first();
        if (!(await downloadControl.isVisible().catch(() => false)))
            throw new Error("Flow media detail page does not expose a visible Download control.");
        let download = await Promise.all([
            page.waitForEvent("download", { timeout: 10_000 }).catch(() => undefined), downloadControl.click(),
        ]).then(([value]) => value);
        if (!download) {
            const menuItem = page.getByRole("menuitem", { name: /Tamaño original|Original size|原始|原图|1080p|720p/i }).first();
            if (!(await menuItem.isVisible().catch(() => false)))
                throw new Error("Download menu opened, but no supported original-size item was found.");
            download = await Promise.all([page.waitForEvent("download", { timeout: 30_000 }), menuItem.click()]).then(([value]) => value);
        }
        if (!download)
            throw new Error("Flow did not produce a download.");
        const saved = await this.saveDownload(download, input.destinationDir, input.fileName, page.url());
        return { ...saved, media, bytes: (await stat(saved.path)).size };
    }
    async close() {
        const context = this.context;
        this.context = undefined;
        this.page = undefined;
        await context?.close();
    }
    async ensurePage() {
        if (!this.context) {
            const context = await chromium.launchPersistentContext(this.config.profileDir, {
                executablePath: this.config.browserExecutable,
                headless: false,
                viewport: null,
                acceptDownloads: true,
                ignoreDefaultArgs: ["--no-sandbox"],
                args: ["--no-first-run", "--disable-default-apps", "--start-maximized"],
            });
            this.context = context;
            context.once("close", () => {
                if (this.context === context) {
                    this.context = undefined;
                    this.page = undefined;
                }
            });
        }
        if (!this.page || this.page.isClosed()) {
            this.page = this.context.pages().find((candidate) => FLOW_HOSTS.some((host) => candidate.url().includes(host))) ?? this.context.pages()[0] ?? await this.context.newPage();
        }
        return this.page;
    }
    async inspectMedia() {
        // PARCHE: las miniaturas ya no tienen enlace /edit/; son <img|video data-media-id> dentro de <flow-image-tile>/<flow-video-tile>.
        const page = await this.ensurePage();
        if (/\/edit\//.test(new URL(page.url()).pathname))
            return [];
        const results = [];
        for (const frame of page.frames()) {
            const items = await frame.evaluate(() => Array.from(document.querySelectorAll("img[data-media-id], video[data-media-id]"))
                .filter((element) => element.getClientRects().length > 0 && element.closest("flow-image-tile, flow-video-tile, flow-tile-container"))
                .slice(0, 200)
                .map((element) => {
                const tileId = element.getAttribute("data-media-id") ?? "";
                const tile = element.closest("flow-tile-container") ?? element.parentElement;
                const caption = tile?.querySelector("flow-tile-hover-footer")?.textContent?.replace(/\s+/g, " ").replace(/^(image|videocam|movie)\s*/i, "").trim();
                return {
                    tileId,
                    providerMediaId: undefined,
                    title: caption || element.getAttribute("alt") || tileId,
                    kind: element.tagName === "VIDEO" ? "video" : "image",
                    href: "",
                };
            })).catch(() => []);
            results.push(...items.filter((item) => item.tileId));
        }
        return [...new Map(results.map((item) => [item.tileId, item])).values()];
    }
    async findMedia(input) {
        const normalizedTitle = input.title?.trim().toLocaleLowerCase();
        let lastMatches = [];
        for (let attempt = 0; attempt < 10; attempt += 1) {
            const items = await this.inspectMedia();
            lastMatches = items.filter((item) => (input.mediaId && (item.tileId === input.mediaId || item.providerMediaId === input.mediaId)) ||
                (normalizedTitle && item.title.toLocaleLowerCase().includes(normalizedTitle)));
            if (lastMatches.length === 1)
                return lastMatches[0];
            if (lastMatches.length > 1)
                break;
            await (await this.ensurePage()).waitForTimeout(2_000);
        }
        throw new Error(`Expected one Flow media item, found ${lastMatches.length}. Inspect flow_inspect_page.media and use tileId or providerMediaId.`);
    }
    async saveDownload(download, destinationDirInput, fileName, sourceUrl) {
        const suggestedFileName = download.suggestedFilename();
        const requestedName = fileName ? path.basename(fileName) : suggestedFileName;
        if (!requestedName || requestedName === "." || requestedName === "..")
            throw new Error("Invalid download file name.");
        const destinationDir = path.resolve(destinationDirInput);
        await mkdir(destinationDir, { recursive: true });
        const destination = path.join(destinationDir, requestedName);
        await download.saveAs(destination);
        if ((await stat(destination)).size <= 0)
            throw new Error("Flow download completed with an empty file.");
        return { path: destination, suggestedFileName, sourceUrl };
    }
    validateFlowProjectUrl(projectUrl) {
        const url = new URL(projectUrl);
        if (url.protocol !== "https:" || !FLOW_HOSTS.includes(url.hostname) || !/^\/project\/[0-9a-f-]{36}\/?$/i.test(url.pathname)) {
            throw new Error("Only official Google Flow project URLs are allowed.");
        }
    }
    async detectAuthentication() {
        const page = await this.ensurePage();
        const hostname = new URL(page.url()).hostname;
        if (hostname === "accounts.google.com" || !FLOW_HOSTS.includes(hostname) || new URL(page.url()).pathname.startsWith("/about"))
            return "login_required";
        const signInLinks = page.locator("a[href*='accounts.google.com']").filter({ hasText: /sign in|iniciar sesión|登录|登入/i });
        return await signInLinks.count() ? "login_required" : "signed_in";
    }
    async visibleControls(selector) {
        const page = await this.ensurePage();
        const controls = [];
        const frames = page.frames();
        for (let frameIndex = 0; frameIndex < frames.length; frameIndex += 1) {
            const locator = frames[frameIndex].locator(selector);
            const count = Math.min(await locator.count(), 200);
            for (let index = 0; index < count; index += 1) {
                const item = locator.nth(index);
                if (!(await item.isVisible().catch(() => false)))
                    continue;
                const label = await this.controlLabel(item);
                if (label)
                    controls.push({ locator: item, label, frame: frameIndex });
            }
        }
        return controls;
    }
    async controlLabel(locator) {
        return locator.evaluate((element) => {
            const html = element;
            let label = html.getAttribute("aria-label") ?? html.getAttribute("placeholder") ?? html.getAttribute("title") ?? html.innerText ?? html.textContent ?? "";
            if (!label.trim() && html.isContentEditable && html.closest("flow-prompt-box, flow-base-prompt-box"))
                label = "Prompt";
            return label.replace(/\s+/g, " ").trim().slice(0, 300);
        }).catch(() => "");
    }
    async visibleExactText(label) {
        const page = await this.ensurePage();
        const collect = async (exact) => {
            const matches = [];
            const frames = page.frames();
            for (let frameIndex = 0; frameIndex < frames.length; frameIndex += 1) {
                const locator = frames[frameIndex].getByText(label, { exact });
                const count = Math.min(await locator.count(), 20);
                for (let index = 0; index < count; index += 1) {
                    const item = locator.nth(index);
                    if (await item.isVisible().catch(() => false))
                        matches.push({ locator: item, label, frame: frameIndex });
                }
            }
            return matches;
        };
        const exactMatches = await collect(true);
        return exactMatches.length > 0 ? exactMatches : collect(false);
    }
    chooseControl(controls, label, index, kind) {
        if (typeof index === "number") {
            if (!controls[index])
                throw new Error(`${kind} index ${index} does not exist.`);
            return controls[index];
        }
        if (!label)
            throw new Error(`Provide an exact ${kind} label or index from flow_inspect_page.`);
        const normalized = label.trim().toLocaleLowerCase();
        const matches = controls.filter((control) => control.label.toLocaleLowerCase() === normalized);
        if (matches.length !== 1)
            throw new Error(`Expected exactly one ${kind} labelled "${label}", found ${matches.length}. Inspect the page and use an index.`);
        return matches[0];
    }
}
//# sourceMappingURL=flow-adapter.js.map