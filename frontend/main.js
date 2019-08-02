const S = {
    proj: null // string = path/to/Project1, null = disconnected
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

async function firstRun() {
    while (S.proj == null) {
        await delay(50);
        S.proj = await rubyeval("$data_system.game_title");
    }
    $("#game_title").textContent = S.proj;
    status(`Opened project [${S.proj}]`);
}

const evalResults = new Map();
async function rubyeval(text) {
    const startTime = Date.now();
    const { data: id } = await axios.post("/eval", text);
    if (!id) return null;
    await delay(50);
    for (let i = 0; !evalResults.has(id); ++i) {
        await delay(200);
        if (i > 50) {
            firstRun();
            return null;
        }
    }
    const value = evalResults.get(id);
    evalResults.delete(id);
    const elapsedTime = Date.now() - startTime;
    $("#ping").textContent = `${elapsedTime}ms`;
    return value;
}

firstRun();

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
Mousetrap(input).bind({
    async enter(e) {
        e.preventDefault();
        if (!input.value) return;
        const { data: valid } = await axios.post("/check", input.value);
        if (valid) {
            const code = `(${input.value}).inspect`;
            const prompt = input.value.split("\n").join("\n   ");
            output.append(`>> ${prompt}\n`);
            input.value = "";
            autosize.update(input);
            const ret = await rubyeval(code);
            if (ret != null) output.append(`=> ${ret}\n`);
        } else {
            insertText(input, "\n");
        }
    },
    ["ctrl+enter"](e) {
        insertText(input, "\n");
    },
    tab(e) {
        e.preventDefault();
        indentTextarea(input);
    },
    ["ctrl+l"](e) {
        e.preventDefault();
        output.innerHTML = "";
    }
});
