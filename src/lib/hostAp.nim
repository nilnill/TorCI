import asyncdispatch, tables, osproc, sequtils, strutils, strformat
import re, os
import ".." / [types, utils]
import sys
from utils as libutils import hostapd, hostapdBak, crda

#proc getModuleName*(net: NetInterfaces; name: NetInterKind): Future[string] {.async.} =
# const
#   hostapd = "/etc" / "hostapd" / "hostapd.conf"
#   hostapdBak = "/etc" / "hostapd" / "hostapd.conf.tbx"
#   crda = "/etc" / "default" / "crda"

const
  channels = {
    "ga": (1, 0), "gb": (1, 1), "gc": (2, 0), 
    "gd": (2, 1), "ge": (3, 0), "gf": (3, 1),
    "gg": (4, 0), "gh": (4, 1), "gi": (5, 0), 
    "gj": (5, 1), "gk": (6, 0), "gl": (6, 1), 
    "gm": (7, 0), "gn": (8, 0), "go": (8, 1), 
    "gp": (8, 1), "gq": (9, 0), "gr": (9, 1), 
    "gs": (10, 0), "gt": (10, 1), "gu": (11, 0),
    "gv": (11, 1),
    "aa": (36, 0), "ab": (36, 1), "ac": (40, 0),
    "ad": (40, 1), "ae": (44, 0), "af": (44, 1),
    "ag": (48, 0), "ah": (48, 1)
  }.toOrderedTable()

proc parseConf*(s: seq[string]): Future[TableRef[string, string]] {.async.} =
  #var tuple_data = tuple[string, string]
  var table = newTable[string, string]()
  for v in s:
    if v != "":
      if not v.startsWith("#"):
        let parsedStr = split(v, "=")
        #for i in parsed_str:
        #table.({parsed_str[0]: parsed_str[1]}.newTable)
        table[parsedStr[0]] = parsedStr[1]
  return table

proc isValid(s, flag: string): tuple[ret: bool, msg: string]=
  case flag
  of "ssid":
    if s.len > 32:
      return (false, "Please set the SSID to 32 characters or less.")
    elif s.match(re"^(^[A-Za-z0-9\-\_]+$)"):
      return (true, "")
    else:
      return (false, "Invalid SSID")

  of "band":
    if s.len == 0: return
    if s.len == 1 and s.match(re"^(a|g)$"):
      return (true, "")
    else:
      return (false, "Invalid band")

  of "channel":
    if s.len == 0: return
    if channels.hasKey(s):
      return (true, "")
    else:
      return (false, "Invalid channel")

  of "password":
    if s.len > 64:
      return (false, "Please set the password to 64 characters or less.")
    elif s.len < 8:
      return (false, "Please set the password to 8 characters or more")
    else:
      return (true, "")

  else:
    return

proc getCrda(): string =
  try:
    let f = readFile(crda)
    for v in f.splitLines():
      if v.startsWith("REGDOMAIN="):
        let vv = v.split("=")
        return vv[1]
  except:
    return

proc changeCrda() =
  try:
    var country: string
    var f = readFile(crda)
    f = f.replace(re"REGDOMAIN=.*", "REGDOMAIN=" & country)
    crda.writeFile(f)
  except:
    return

proc getHostApStatus*(): Future[bool] {.async.} =
  const cmd = "sudo systemctl is-active hostapd"
  let ret = execCmdEx(cmd)
  let sta = ret.output.splitLines()[0]
  if sta == "active":
    return true

  # # This last part resets the dhcp server and opens the iptables to access TorBox
  # # This fundtion has to be used after an ifup command
  # # Important: the right iptables rules to use Tor have to configured afterward
  # discard execCmd("sudo systemctl restart isc-dhcp-server")
  # discard execCmd("sudo /sbin/iptables -F")
  # discard execCmd("sudo /sbin/iptables -t nat -F")
  # discard execCmd("sudo /sbin/iptables -P FORWARD DROP")
  # discard execCmd("sudo /sbin/iptables -P INPUT ACCEPT")
  # discard execCmd("sudo /sbin/iptables -P OUTPUT ACCEPT")

proc disableAp*(flag: string = "") {.async.} =
  try:
    if flag == "permanentry":
      discard execCmd("sudo systemctl mask --now hostapd")
    stopService("hostapd")
    discard execCmd("sudo systemctl daemon-reload")
  except:
    return

proc enableWlan*() {.async.} =
  try:
    discard execCmd("sudo systemctl enable hostapd")
    startService("hostapd")
  except:
    return

proc getHostApConf*(): Future[HostApConf] {.async.} =
    #const copyFile = &"cp {hostapd_path} {hostapd_save}"
  try:
    let apSta = waitFor getHostApStatus()
    var fr = splitLines(readFile(hostapd))
    # fr.delete(0, 5)
    let tb = await parseConf(fr)
    # let crBand = await currentBand()
    # result = {"ssid": tb["ssid"], "band": crBand, "ssidCloak": tb["ignore_broadcast_ssid"]}.newTable
    result = HostApConf(
      isActive: apSta,
      iface: tb["interface"].parseIface(),
      ssid: tb["ssid"],
      band: tb["hw_mode"],
      channel: tb["channel"],
      isHidden: if tb["ignore_broadcast_ssid"] == "1": true else: false,
      password: tb["wpa_passphrase"]
    )
  except:
    return

proc setHostApConf*(conf: OrderedTable[string, string]): Future[
  tuple[
    allgreen: bool,
    rets: seq[
      tuple[
        status: Status,
        msg: string
      ]
    ]
  ]
  ] {.async.} =
  try:
    copyFile(hostapd, hostapdBak)
    var
      fr = readFile(hostapd)
      existsBad: bool
      succeed: int

    for k, v in conf.pairs:
      if v.len == 0: continue

      case k
      of "ssid":
        let iv = isValid(v, "ssid")

        if iv.ret:
          fr = fr.replace(re"ssid=.*", "ssid=" & v)
          succeed += 1

        else:
          existsBad = true
          result.rets.add (failure, iv.msg)

      of "channel":
        let iv = isValid(v, "channel")

        if iv.ret:
          let (channel, hf) = channels[v]
          fr = fr.replace(re"channel=.*", "channel=" & $channel)
          succeed += 1

          if hf == 0:
            fr = fr.replace("vht_oper_chwidth=1", "#vht_oper_chwidth=1")
            fr = fr.replace("vht_oper_centr_freq_seg0_idx=42", "#vht_oper_centr_freq_seg0_idx=42")

          else:
            fr = fr.replace("#vht_oper_chwidth=1", "vht_oper_chwidth=1")
            fr = fr.replace("#vht_oper_centr_freq_seg0_idx=42", "vht_oper_centr_freq_seg0_idx=42")

        else:
          existsBad = true
          result.rets.add (failure, iv.msg)

      of "band":
        let iv = isValid(v, "band")
        if iv.ret:
          if v == "a":
            let coCode = getCrda()

            if coCode == "00":
              changeCrda()
            fr = fr.replace("hw_mode=g", "hw_mode=" & v)
            fr = fr.replace(re"channel.*", "channel=36")
            fr = fr.replace("#ht_capab=[HT40-][HT40+][SHORT-GI-20][SHORT-GI-40][DSSS_CCK-40]", "ht_capab=[HT40-][HT40+][SHORT-GI-20][SHORT-GI-40][DSSS_CCK-40]")

          else:
            fr = fr.replace("hw_mode=a", "hw_mode=g")
            fr = fr.replace(re"channel.*", "channel=6")
            fr = fr.replace("vht_oper_chwidth=1", "#vht_oper_chwidth=1")
            fr = fr.replace("vht_oper_centr_freq_seg0_idx=42", "#vht_oper_centr_freq_seg0_idx=42")

          succeed += 1

        else:
          existsBad = true
          result.rets.add (failure, iv.msg)
          
      of "password":
        let iv = isValid(v, "password")
        if iv.ret:
          fr = fr.replace(re"wpa_passphrase=.*", "wpa_passphrase=" & v)
          succeed += 1

        else:
          existsBad = true
          result.rets.add (failure, iv.msg)

      of "hideSsid":
        let input: int = if v == "1": 1 
                         else: 0
        fr = fr.replacef(re"ignore_broadcast_ssid=.*", "ignore_broadcast_ssid=" & $input)
        succeed += 1

    if succeed > 0:
      writeFile(hostapd, fr)
      if not existsBad: result.allgreen = true

  except:
    return

when isMainModule:
  when defined(dhclient):
    const cmd = "ps -ax | grep \"[d]hclient.wlan1\""
    let ps = execCmdEx(cmd)
    for v in ps.output.splitLines():
      let m = v.splitWhitespace(maxsplit = 4)
      let app = m[4]
      echo "app: ", app
      echo "line: ", m