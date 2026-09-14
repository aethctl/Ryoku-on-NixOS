local K = require("modules.rebind")

hl.bind(K("Print"), hl.dsp.exec_cmd("flock -n -o /tmp/ryoshot.lock qs -c ryoshot"))
hl.bind(K("SHIFT + Print"), hl.dsp.exec_cmd("flock -n -o /tmp/ryoshot.lock env RYOSHOT_MODE=monitor qs -c ryoshot"))
