.pragma library

// Turning raw counters into one number a person can read at a glance.
//
// The headline figure is "strain": how hard the machine is working to keep up,
// on a 0..1 scale. It is deliberately NOT an average of CPU, memory and I/O.
// A machine with an idle CPU that is swapping itself to death feels broken,
// and averaging would report it as half-busy. What you feel is whichever
// resource has run out first, so strain is the MAX of the sub-scores and the
// widget names the one that won.
//
// Each sub-score is scaled so that 1.0 means "this resource is now the thing
// holding the machine back", not "this resource is at its numerical maximum".

function clamp01(v) {
  if (!isFinite(v)) return 0
  return v < 0 ? 0 : (v > 1 ? 1 : v)
}

// Pressure Stall Information is the kernel's own answer to "is anything
// actually waiting". `full` avg10 is the share of the last ten seconds in
// which EVERY task was stalled on this resource, so single digits already
// mean real, felt stalling; 20% is a machine in trouble.
function psiScore(fullAvg10) {
  return clamp01((Number(fullAvg10) || 0) / 20)
}

// Temperature only counts as strain once the part is near the point where the
// governor starts clawing back clocks. Below 50C the fan curve is the only
// thing that cares, so that is the floor rather than 0C.
function thermalScore(temp, max) {
  if (!isFinite(temp) || !isFinite(max) || max <= 50) return 0
  return clamp01((temp - 50) / (max - 50))
}

function derive(sample, prev) {
  var out = {
    ok: !!sample,
    cpu: 0,
    memUsed: 0,
    memUsedBytes: 0,
    memTotalBytes: 0,
    swapUsedBytes: 0,
    swapTotalBytes: 0,
    temp: null,
    tempMax: null,
    netRx: 0,
    netTx: 0,
    diskRead: 0,
    diskWrite: 0,
    load: [0, 0, 0],
    cores: 1,
    uptime: 0,
    running: 0,
    top: [],
    topMem: [],
    scores: {},
    strain: 0,
    driver: "cpu",
    driverLabel: "CPU"
  }
  if (!sample) return out

  out.cores = Number(sample.cores) || 1
  out.uptime = Number(sample.uptime) || 0
  out.running = (sample.procs && Number(sample.procs.running)) || 0
  out.load = sample.load || [0, 0, 0]
  out.top = sample.top || []
  out.topMem = sample.topMem || []

  // ---- CPU. Needs two samples; with only one we report 0 rather than
  // guessing, and the first tick after the widget loads is simply blank.
  if (prev && sample.cpu && prev.cpu) {
    var dTotal = sample.cpu.total - prev.cpu.total
    var dIdle = sample.cpu.idle - prev.cpu.idle
    if (dTotal > 0) out.cpu = clamp01((dTotal - dIdle) / dTotal)
  }

  // ---- Memory. MemAvailable is the kernel's estimate of what a new
  // allocation could get hold of without pushing anything to swap, which is a
  // far better "how full is it really" than MemFree — page cache is not
  // pressure.
  var mem = sample.mem || {}
  var memTotal = Number(mem.total) || 0
  var memAvail = Number(mem.available) || 0
  if (memTotal > 0) {
    out.memUsed = clamp01((memTotal - memAvail) / memTotal)
    out.memTotalBytes = memTotal * 1024
    out.memUsedBytes = (memTotal - memAvail) * 1024
  }
  var swapTotal = Number(mem.swapTotal) || 0
  var swapFree = Number(mem.swapFree) || 0
  out.swapTotalBytes = swapTotal * 1024
  out.swapUsedBytes = (swapTotal - swapFree) * 1024

  // ---- Temperature
  var temp = sample.temp || {}
  out.temp = isFinite(temp.cpu) ? temp.cpu : null
  out.tempMax = isFinite(temp.cpuMax) ? temp.cpuMax : null
  out.tempNvme = isFinite(temp.nvme) ? temp.nvme : null

  // ---- Rates. Counters are monotonic until they wrap or an interface is
  // reset, so a negative delta is discarded rather than shown as a spike.
  if (prev && isFinite(prev.__t) && isFinite(sample.__t)) {
    var dt = sample.__t - prev.__t
    if (dt > 0.05 && dt < 60) {
      out.netRx = rate(sample.net && sample.net.rx, prev.net && prev.net.rx, dt)
      out.netTx = rate(sample.net && sample.net.tx, prev.net && prev.net.tx, dt)
      out.diskRead = rate(sample.disk && sample.disk.read, prev.disk && prev.disk.read, dt)
      out.diskWrite = rate(sample.disk && sample.disk.write, prev.disk && prev.disk.write, dt)
    }
  }

  // ---- Sub-scores
  var psi = sample.psi || {}
  out.scores = {
    cpu: out.cpu,
    memory: Math.max(out.memUsed, psiScore(psi.memFull)),
    io: psiScore(psi.ioFull),
    thermal: thermalScore(out.temp, out.tempMax)
  }
  out.psi = psi

  var labels = { cpu: "CPU", memory: "Memory", io: "Disk I/O", thermal: "Heat" }
  var best = "cpu"
  for (var k in out.scores) {
    if (out.scores[k] > out.scores[best]) best = k
  }
  out.strain = clamp01(out.scores[best])
  out.driver = best
  out.driverLabel = labels[best]
  return out
}

function rate(now, before, dt) {
  var d = (Number(now) || 0) - (Number(before) || 0)
  if (!(d >= 0)) return 0
  return d / dt
}

// A word for the gauge, so the panel says something even before you read the
// numbers. Thresholds match the colour ramp in StrainGauge.
function moodFor(strain) {
  if (strain < 0.25) return "Idle"
  if (strain < 0.50) return "Working"
  if (strain < 0.75) return "Busy"
  if (strain < 0.90) return "Under load"
  return "Struggling"
}

// ---------------------------------------------------------------- formatting

function bytes(n) {
  n = Number(n) || 0
  if (n < 1024) return Math.round(n) + " B"
  var units = ["kB", "MB", "GB", "TB"]
  var i = -1
  do { n /= 1024; i++ } while (n >= 1024 && i < units.length - 1)
  return (n >= 100 ? n.toFixed(0) : n.toFixed(1)) + " " + units[i]
}

function rateText(n) {
  return bytes(n) + "/s"
}

function percent(v) {
  return Math.round(clamp01(v) * 100) + "%"
}

function tempText(c) {
  return isFinite(c) && c !== null ? Math.round(c) + "°C" : "—"
}

function uptimeText(seconds) {
  seconds = Math.max(0, Math.floor(Number(seconds) || 0))
  var d = Math.floor(seconds / 86400)
  var h = Math.floor((seconds % 86400) / 3600)
  var m = Math.floor((seconds % 3600) / 60)
  if (d > 0) return d + "d " + h + "h"
  if (h > 0) return h + "h " + m + "m"
  return m + "m"
}
