const S = {
    proj: null, // string = 'Project1', null = disconnected
    path: null // 'path/to/Project1'
};

window.S = S;

eva.replace();

function $(sel) {
    return document.querySelector(sel);
}

function $$(sel) {
    return Array.from(document.querySelectorAll(sel));
}

autosize($("#console_input"));

EventTarget.prototype.on = EventTarget.prototype.addEventListener;
window.on("resize", _ => {
    autosize.update($("#console_input"));
});

const contextMenus = new Set();

for (const item of $$(".menu > .item[data-target]")) {
    const target = $(item.dataset.target);
    contextMenus.add(target);
    const { left, bottom } = item.getClientRects()[0];
    item.on("click", _ => {
        for (const t of contextMenus) {
            t.hidden = true;
            t.style.left = left + "px";
            t.style.right = "";
            t.style.top = bottom + "px";
        }
        target.hidden = false;
    });
}

document.body.on("click", e => {
    const t = e.target;
    const s = t && t.dataset && t.dataset.target && $(t.dataset.target);
    for (const menu of contextMenus) menu.hidden = s !== menu;
    if (!s && !$("#console").hidden) $("#console_input").focus();
});

const activities = new Set();
for (const item of $$(".activity > .item[data-target]")) {
    const target = $(item.dataset.target);
    activities.add(target);
    item.on("click", e => {
        const isActive = item.classList.contains("active");
        for (const i of $$(".activity > .item[data-target]")) {
            i.classList.remove("active");
        }
        item.classList.add("active");
        const sidebar = target.querySelector(".sidebar");
        if (isActive) {
            sidebar && (sidebar.hidden ^= true);
        } else {
            for (const t of activities) {
                t.hidden = target !== t;
            }
            sidebar && (sidebar.hidden = false);
        }
    });
}

function status(msg) {
    $("#status_message").textContent = msg;
}

status("Start the game to use rrnide!");

const delay = ms => new Promise(r => setTimeout(r, ms));

const evalResults = new Map();
async function rubyeval(text) {
    const startTime = Date.now();
    const { data: id } = await axios.post("/eval", text);
    if (!id) return null;
    await delay(50);
    for (let i = 0; !evalResults.has(id); ++i) {
        await delay(200);
        if (i > 50) {
            $("#game_title").textContent = "No Project";
            $("#ping").textContent = "Disconnected";
            return null;
        }
    }
    const value = evalResults.get(id);
    evalResults.delete(id);
    const elapsedTime = Date.now() - startTime;
    $("#ping").textContent = `${elapsedTime}ms`;
    return value;
}

async function keepAlive() {
    await delay(50);
    while (true) {
        const ret = await rubyeval("$data_system.game_title");
        if ((S.proj = ret) != null) {
            $("#game_title").textContent = S.proj;
            status(`Connected [${S.proj}]`);
            S.path = await rubyeval("Dir.pwd");
        }
        await delay(10000);
    }
}
keepAlive();

const output = $("#console_output");
const ws = new WebSocket("ws://localhost:8080");
ws.on("message", e => {
    const [meth, ...args] = JSON.parse(Base64.decode(e.data));
    if (meth === "return") {
        const [value, id] = args;
        evalResults.set(id, value);
    } else if (meth === "stdout" || meth === "stderr") {
        const [str] = args;
        output.append(str);
    }
});

window.rubyeval = rubyeval;

// https://github.com/fregante/insert-text-textarea
function insertText(textarea, text) {
    textarea.focus();
    if (document.execCommand("insertText", false, text)) return;
    textarea.setRangeText(
        text,
        textarea.selectionStart,
        textarea.selectionEnd,
        "end"
    );
    textarea.dispatchEvent(
        new InputEvent("input", {
            data: text,
            inputType: "insertText",
            isComposing: false
        })
    );
}

const TAB = "  ";

// https://github.com/fregante/indent-textarea
function indentTextarea(textarea) {
    const { selectionStart, selectionEnd, value } = textarea;
    const matchData = value.slice(selectionStart, selectionEnd).match(/^|\n/g);
    const linesCount = matchData ? matchData.length : 0;
    if (linesCount > 1) {
        const firstLineStart = value.lastIndexOf("\n", selectionStart) + 1;
        textarea.setSelectionRange(firstLineStart, selectionEnd);
        const newSelection = textarea.value.slice(firstLineStart, selectionEnd);
        const indentedText = newSelection.replace(/^|\n/g, `$&${TAB}`);
        insertText(textarea, indentedText);
        textarea.setSelectionRange(
            selectionStart + TAB.length,
            selectionEnd + linesCount * TAB.length
        );
    } else {
        insertText(textarea, TAB);
    }
}

const input = $("#console_input");
const inputHistory = [];
const MAX_HISTORY = 120;
let inputHistoryCursor = -1;
Mousetrap(input).bind({
    async enter(e) {
        e.preventDefault();
        inputHistoryCursor = -1;
        if (!input.value) return;
        const { data: valid } = await axios.post("/check", input.value);
        if (valid) {
            inputHistory.unshift(input.value);
            while (inputHistory.length > MAX_HISTORY) {
                inputHistory.pop();
            }
            const code = `(${input.value}).inspect`;
            const prompt = input.value.split("\n").join("\n   ");
            output.append(`>> ${prompt}\n`);
            input.value = "";
            autosize.update(input);
            const ret = await rubyeval(code);
            if (ret != null) {
                output.append(`=> ${ret}\n`);
                autosize.update(input);
            }
        } else {
            insertText(input, "\n");
        }
    },
    ["ctrl+enter"](e) {
        inputHistoryCursor = -1;
        insertText(input, "\n");
    },
    tab(e) {
        e.preventDefault();
        inputHistoryCursor = -1;
        indentTextarea(input);
    },
    ["ctrl+l"](e) {
        e.preventDefault();
        inputHistoryCursor = -1;
        output.innerHTML = "";
    },
    up(e) {
        if (!inputHistory.length) return;
        e.preventDefault();
        ++inputHistoryCursor;
        if (inputHistoryCursor > inputHistory.length - 1)
            inputHistoryCursor = inputHistory.length - 1;
        input.value = inputHistory[inputHistoryCursor];
        autosize.update(input);
    },
    down(e) {
        if (!inputHistory.length) return;
        e.preventDefault();
        --inputHistoryCursor;
        if (inputHistoryCursor < 0) {
            inputHistoryCursor = -1;
            input.value = "";
        } else {
            input.value = inputHistory[inputHistoryCursor];
        }
        autosize.update(input);
    }
});

function elt(tag, className, ...children) {
    const el = document.createElement(tag);
    if (className) el.className = className;
    el.append(...children);
    return el;
}

function dirtyAuthors(meta) {
    if (meta.author === "unknown") {
        if (meta.taroxd) meta.author = "taroxd";
    }
}

async function installPlugin(file) {
    if (await axios.post("/install", [file, S.path])) {
        await delay(50);
        $("#plugin_refresh").click();
    }
}

async function uninstallPlugin(destfile) {
    if (await axios.post("/uninstall", [destfile, S.path])) {
        await delay(50);
        $("#plugin_refresh").click();
    }
}

async function updatePlugin(file) {
    if (await axios.post("/install", [file, S.path])) {
        await delay(50);
        $("#plugin_refresh").click();
    }
}

function basename(path) {
    if (typeof path !== "string") return;
    return path.split(/[\\/]/).pop();
}

let plugins = [],
    plugin_elements = [];
$("#plugin_refresh").on("click", async _ => {
    const ret = await axios.get("/plugins");
    plugins = ret.data;
    const query = "PluginManager.scripts.map { |f, _, m| [f, m] }";
    const metas = await rubyeval(query);
    $("#plugin_list").innerHTML = "";
    plugin_elements = [];
    for (const { file, meta, mtime } of plugins) {
        dirtyAuthors(meta);
        const action = elt("button", "action", "Install");
        if (metas != null) {
            const name = basename(file);
            const exist = metas.find(([f, m]) => basename(f) === name);
            const same = exist ? exist[1] === mtime : false;
            if (same) {
                action.classList.add("uninstall");
                action.textContent = "Uninstall";
                action.on("click", _ => {
                    uninstallPlugin(exist[0]);
                });
            } else if (exist) {
                action.classList.add("update");
                action.textContent = "Update";
                action.on("click", _ => {
                    updatePlugin(file);
                });
            } else {
                action.on("click", _ => {
                    installPlugin(file);
                });
            }
        } else {
            action.disabled = true;
        }
        // prettier-ignore
        const item = elt("div", "item",
            elt("div", "titleline",
                elt("span", "title", meta.display),
                elt("span", "version", meta.version || "")),
            elt("div", "desc", meta.help),
            elt("div", "footer",
                elt('span', 'author', meta.author),
                action));
        item.dataset.file = file;
        item.on("click", _ => {
            for (const el of plugin_elements) {
                el.classList.remove("active");
            }
            item.classList.add("active");
        });
        $("#plugin_list").append(item);
        plugin_elements.push(item);
    }
});

S.plugins = plugins;
