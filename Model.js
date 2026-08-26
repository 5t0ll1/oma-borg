function parseStatus(raw) {
  var text = String(raw || "").trim()
  if (text === "") return defaultStatus()
  try {
    var parsed = JSON.parse(text)
    if (!parsed || typeof parsed !== "object") return defaultStatus()
    parsed.archives = Array.isArray(parsed.archives) ? parsed.archives : []
    return parsed
  } catch (e) {
    var failed = defaultStatus()
    failed.ok = false
    failed.lastError = "Failed to parse Borg status"
    return failed
  }
}

function defaultStatus() {
  return {
    ok: true,
    vortaInstalled: false,
    borgInstalled: false,
    vortaRunning: false,
    backupRunning: false,
    profileName: "",
    repoHost: "",
    scheduleMode: "off",
    scheduleLabel: "manual",
    scheduleCount: 4,
    scheduleUnit: "hours",
    makeUpMissed: true,
    intervalSec: 14400,
    lastBackupAt: "",
    lastBackupTs: 0,
    lastBackupAgeSec: null,
    lastBackupAgeLabel: "never",
    lastReturncode: null,
    lastOk: false,
    archives: [],
    statusText: "Checking…"
  }
}

function ageLabel(seconds) {
  if (seconds === null || seconds === undefined || !isFinite(seconds)) return "never"
  var sec = Math.max(0, Math.floor(seconds))
  if (sec < 60) return "just now"
  var minutes = Math.floor(sec / 60)
  if (minutes < 60) return minutes + "m ago"
  var hours = Math.floor(minutes / 60)
  if (hours < 48) return hours + "h ago"
  var days = Math.floor(hours / 24)
  return days + "d ago"
}

function deriveState(status, nowSec, staleAfterHours, failedAfterHours) {
  if (status && status.backupRunning) return "running"
  if (status && status.lastReturncode !== null && status.lastReturncode !== undefined
      && status.lastReturncode > 1) return "failed"
  var ts = status && status.lastBackupTs ? Number(status.lastBackupTs) : 0
  if (!ts) return status && status.vortaInstalled ? "never" : "missing"
  var ageHours = Math.max(0, (nowSec - ts) / 3600)
  if (ageHours >= failedAfterHours) return "overdue"
  if (ageHours >= staleAfterHours) return "stale"
  return "ok"
}

function stateLabel(state, statusText) {
  if (state === "running") return "Backing up"
  if (state === "failed") return "Last backup failed"
  if (state === "overdue") return "Backup overdue"
  if (state === "stale") return "Backup getting old"
  if (state === "never") return "No backups yet"
  if (state === "missing") return "Vorta is not installed"
  return statusText || "Up to date"
}

function resultLabel(code) {
  if (code === null || code === undefined) return "—"
  if (code === 0) return "ok"
  if (code === 1) return "ok (warnings)"
  return "failed (" + code + ")"
}

function nextLabel(status, nowSec) {
  if (!status) return "—"
  if (status.scheduleMode !== "interval") return status.scheduleLabel || "manual"
  var interval = Number(status.intervalSec || 0)
  var last = Number(status.lastBackupTs || 0)
  if (!interval || !last) return status.scheduleLabel || "—"
  var next = last + interval
  if (next <= nowSec) {
    if (status.makeUpMissed) return "on next catch-up"
    return "waiting for next window"
  }
  return "in " + ageLabel(next - nowSec).replace(" ago", "")
}
