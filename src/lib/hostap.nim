import std / [ options, strutils,
  os, osproc, asyncdispatch, re, tables
]
import results
import karax / [ karaxdsl, vdom ]
import ../ settings
import ../ views / renderutils
import sys / [ service, iface ]

const
  model3* = "Raspberry Pi 3 Model B Rev"
  hostapd* = "/etc" / "hostapd" / "hostapd.conf"
  crda* = "/etc" / "default" / "crda"
  hostapdBakup* = "/etc" / "hostapd" / "hostapd.conf.tbx"

type
  HostAp* = ref object of RootObj
    status: HostApStatus
    conf: HostApConf

  HostApStatus* = ref object of RootObj
    isActive: bool

  HostApConf* = ref object of RootObj
    iface: IfaceKind 
    ssid: string
    password: string
    band: char
    channel: string
    isHidden: bool 
    power: string

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

method getIface*(hostapConf: HostApConf): Option[IfaceKind] {.base.} =
  if hostapConf.iface.isIface:
    return some(hostapConf.iface)

method getIface*(hostap: HostAp): Option[IfaceKind] {.base.} =
  hostap.conf.getIface

method getSSID*(hostapConf: HostApConf): Option[string] {.base.} =
  if hostapConf.ssid.len > 0:
    return some hostapConf.ssid

method getSSID*(hostap: HostAp): Option[string] {.base.} =
  hostap.conf.getSSID

method getBand*(hostapConf: HostApConf): Option[char] {.base.} =
  if hostApConf.band.ord != 00:
    return some hostApConf.band

method getBand*(hostap: HostAp): Option[char] {.base.} =
  hostap.conf.getBand

method getChannel*(hostapConf: HostApConf): Option[string] {.base.} =
  if hostapConf.channel.len > 0:
    return some hostapConf.channel 

method getChannel*(hostap: HostAp): Option[string] {.base.} =
  hostap.conf.getChannel

method getPassword*(hostapConf: HostApConf): Option[string] {.base.} =
  if hostapConf.password.len > 0:
    return some hostapConf.password

method getPassword*(hostap: HostAp): Option[string] {.base.} =
  hostap.conf.getPassword

method isHidden*(hostapConf: HostApConf): bool {.base.} =
  hostapConf.isHidden

method isHidden*(hostap: HostAp): bool {.base.} =
  isHidden(hostap.conf)

method isActive*(status: HostApStatus): bool {.base.} =
  status.isActive

method isActive*(hostap: HostAp): bool {.base.} =
  isActive(hostap.status)

# proc parseIface(iface: string): IfaceKind =
#   parseEnum[IfaceKind](iface, unkwnIface) 

proc iface*(hostapConf: var HostApConf, iface: string): Result[void, string] =
  let kind = iface.parseIfaceKind()
  if kind.isSome:
    hostapConf.iface = kind.get
  
  result.err("Invalid interface")

proc iface*(hostap: var HostAp, iface: string): Result[void, string] =
  ?iface(hostap.conf, iface)

proc ssid*(hostapConf: var HostApConf, ssid: string): Result[void, string] =
  if ssid.len > 32:
    result.err "Please set the SSID to 32 characters or less."
  elif ssid.match(re"^(^[A-Za-z0-9\-\_]+$)"):
    hostapConf.ssid = ssid
    result.ok
  else:
    result.err "Invalid SSID"

proc ssid*(hostap: var HostAp, ssid: string): Result[void, string] =
  ?ssid(hostap.conf, ssid)

proc band*(hostapConf: var HostApConf, band: char): Result[void, string] =
  let ord_band = ord(band.toLowerAscii)
  if ord_band == 97 or ord_band == 103:
    hostapConf.band = band
    result.ok
  else:
    result.err "Invalid band"

proc band*(hostapConf: var HostApConf, band: string): Result[void, string] =
  # if band.len == 1 and band.match(re"^(a|g)$"):
  if band.len == 1:
    ?band(hostapConf, cast[char](band))
  else:
    result.err "Invalid band"

proc band*(hostap: var HostAp, band: string): Result[void, string] =
  ?band(hostap.conf, band)

proc channel*(hostapConf: var HostApConf, channel: string): Result[void, string] =
  if channels.hasKey(channel):
    hostApConf.channel = channel
    result.ok
  else:
    result.err "Invalid channel"

proc channel*(hostap: var HostAp, channel: string): Result[void, string] =
  ?channel(hostap.conf, channel)

proc password*(hostapConf: HostApConf, password: string): Result[void, string] =
  if password.len > 64:
    result.err "Please set the password to 64 characters or less."
  elif password.len < 8:
    result.err "Please set the password to 8 characters or more"
  else:
    hostapConf.password = password
    result.ok

proc password*(hostap: HostAp, password: string): Result[void, string] =
  ?password(hostap.conf, password)

proc cloak*(hostapConf: HostApConf, boolean: bool) =
  hostapConf.isHidden = boolean

proc status*(hostap: HostAp, status: HostApStatus) =
  hostap.status = status

proc active*(status: var HostApStatus, isActive: bool) =
  status.isActive = isActive

proc active*(hostap: var HostAp, isActive: bool) =
  active(hostap.status, isActive)

proc hostapdIsActive*(): Future[bool] {.async.} =
  const cmd = "sudo systemctl is-active hostapd"
  let
    ret = execCmdEx(cmd)
    sta = ret.output.splitLines()[0]
  if sta == "active":
    return true

proc getHostApConf*(): Future[HostApConf] {.async.} =
  try:
    let lines = splitLines(readFile(hostapd))

    result.new

    for line in lines:
      if (line.len > 0) and (not line.startsWith("#")):
        let pair = split(line, "=")
        case pair[0]
        of "ssid": 
          let _ = ssid(result, pair[1])
        
        of "interface":
          let _ = iface(result, pair[1])

        of "band":
          let _ = band(result, pair[1])

        of "channel":
          let _ = channel(result, pair[1])

        of "ignore_broadcast_ssid":
          if pair[1] == "1":
            result.isHidden = true 

        of "password":
          let _ = password(result, pair[1])
  except:
    return

proc getHostApStatus*(): Future[HostApStatus] {.async.} =
  result.new
  result.isActive = waitFor hostapdIsActive()

proc getHostAp*(): Future[HostAp] {.async.} =
  result.new
  result.conf = waitFor getHostApConf()
  result.status = waitFor getHostApStatus()

proc parseConf*(s: seq[string]): Future[TableRef[string, string]] {.async.} =
  #var tuple_data = tuple[string, string]
  var table = newTable[string, string]()
  for v in s:
    if (v.len > 0) and (not v.startsWith("#")):
      let parsedStr = split(v, "=")
      #for i in parsed_str:
      #table.({parsed_str[0]: parsed_str[1]}.newTable)
      table[parsedStr[0]] = parsedStr[1]
  return table

proc getCrda(): Future[string] {.async.} =
  try:
    let f = readFile(crda)
    for v in f.splitLines():
      if v.startsWith("REGDOMAIN="):
        let vv = v.split("=")
        return vv[1]
  except:
    return

proc changeCrda() {.async.} =
  try:
    var country: string
    var f = readFile(crda)
    f = f.replace(re"REGDOMAIN=.*", "REGDOMAIN=" & country)
    crda.writeFile(f)
  except:
    return

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

method write*(hostapConf: HostApConf) {.base.} =
  try:
    copyFile(hostapd, hostapdBakup)
    var stream = readFile(hostapd)
    
    let ssid = hostapConf.getSSID
    if ssid.isSome:
      stream = stream.replace(re"ssid=.*", "ssid=" & ssid.get)

    let band = hostapConf.getBand
    if band.isSome:
      if band.get == 'a':
        let coCode = waitFor getCrda()
        if coCode == "00":
          waitFor changeCrda()
        stream = stream.replace("hw_mode=g", "hw_mode=" & band.get)
        stream = stream.replace(re"channel.*", "channel=36")
        stream = stream.replace("#ht_capab=[HT40-][HT40+][SHORT-GI-20][SHORT-GI-40][DSSS_CCK-40]", "ht_capab=[HT40-][HT40+][SHORT-GI-20][SHORT-GI-40][DSSS_CCK-40]")

      else:
        stream = stream.replace("hw_mode=a", "hw_mode=g")
        stream = stream.replace(re"channel.*", "channel=6")
        stream = stream.replace("vht_oper_chwidth=1", "#vht_oper_chwidth=1")
        stream = stream.replace("vht_oper_centr_freq_seg0_idx=42", "#vht_oper_centr_freq_seg0_idx=42")

    let sig = hostapConf.getChannel
    if sig.isSome:
      let (channel, hf) = channels[sig.get]
      stream = stream.replace(re"channel=.*", "channel=" & $channel)

      if hf == 0:
        stream = stream.replace("vht_oper_chwidth=1", "#vht_oper_chwidth=1")
        stream = stream.replace("vht_oper_centr_freq_seg0_idx=42", "#vht_oper_centr_freq_seg0_idx=42")

      else:
        stream = stream.replace("#vht_oper_chwidth=1", "vht_oper_chwidth=1")
        stream = stream.replace("#vht_oper_centr_freq_seg0_idx=42", "vht_oper_centr_freq_seg0_idx=42")
      
    let password = hostapConf.getPassword
    if password.isSome:
      stream = stream.replace(re"wpa_passphrase=.*", "wpa_passphrase=" & password.get)
    
    block:
      let cloak = if hostapConf.isHidden: "1" else: "0"
      stream = stream.replacef(re"ignore_broadcast_ssid=.*", "ignore_broadcast_ssid=" & cloak)

    writeFile(hostapd, stream)

  except:
    return

method write*(hostap: HostAp) {.base.} =
  hostap.conf.write

proc renderChannelSelect*(band: char): VNode =
  buildHtml(select(name="channel")):
    option(selected="selected"): text "-- Select a channel --"
    if sysInfo.model == model3:
      option(value="ga"): text "1 at 20 MHz"
      option(value="gc"): text "2 at 20 MHz"
      option(value="ge"): text "3 at 20 MHz"
      option(value="gg"): text "4 at 20 MHz"
      option(value="gi"): text "5 at 20 MHz"
      option(value="gk"): text "6 at 20 MHz (default)"
      option(value="gm"): text "7 at 20 MHz"
      option(value="go"): text "8 at 20 MHz"
      option(value="gq"): text "9 at 20 MHz"
      option(value="gs"): text "10 at 20 MHz"
      option(value="gu"): text "11 at 20 MHz"

    elif band == 'g':
      option(value="ga"): text "1 at 20 MHz"
      option(value="gb"): text "1 at 40 MHz"
      option(value="gc"): text "2 at 20 MHz"
      option(value="gd"): text "2 at 40 MHz"
      option(value="ge"): text "3 at 20 MHz"
      option(value="gf"): text "3 at 40 MHz"
      option(value="gg"): text "4 at 20 MHz"
      option(value="gh"): text "4 at 40 MHz"
      option(value="gi"): text "5 at 20 MHz"
      option(value="gj"): text "5 at 40 MHz"
      option(value="gk"): text "6 at 20 MHz (default)"
      option(value="gl"): text "6 at 40 MHz"
      option(value="gm"): text "7 at 20 MHz"
      option(value="gn"): text "7 at 40 MHz"
      option(value="go"): text "8 at 20 MHz"
      option(value="gp"): text "8 at 40 MHz"
      option(value="gq"): text "9 at 20 MHz"
      option(value="gr"): text "9 at 40 MHz"
      option(value="gs"): text "10 at 20 MHz"
      option(value="gt"): text "10 at 40 MHz"
      option(value="gu"): text "11 at 20 MHz"
      option(value="gv"): text "11 at 40 MHz"

    elif band == 'a':
      option(value="aa"): text "36 at 40 MHz (default)"
      option(value="ab"): text "36 at 80 MHz"
      option(value="ac"): text "40 at 40 MHz"
      option(value="ad"): text "40 at 80 MHz"
      option(value="ae"): text "44 at 40 MHz"
      option(value="af"): text "44 at 80 MHz"
      option(value="ag"): text "48 at 40 MHz"
      option(value="ah"): text "48 at 80 MHz"

proc render*(hostap: HostApConf): VNode =
  buildHtml(tdiv(class="columns width-58")):
    tdiv(class="box"):
      tdiv(class="box-header"):
        text "Config"
        tdiv(class="btn edit-button"):
          icon "sliders"
          input(class="opening-button", `type`="radio", name="popout-button", value="open")
          input(class="closing-button", `type`="radio", name="popout-button", value="close")
          tdiv(class="shadow")
          tdiv(class="editable-box"):
            form(`method`="post", action="/net/wireless", enctype="multipart/form-data"):
              tdiv(class="card-table"):
                label(class="card-title"): text "SSID"
                input(`type`="text", name="ssid", placeholder=hostap.getSSID.get)
              tdiv(class="card-table"):
                label(class="card-title"): text "Band"
                input(`type`="radio", name="band", value="g"): text "2.5GHz"
                input(`type`="radio", name="band", value="a"): text "5GHz"
              tdiv(class="card-table"):
                label(class="card-title"): text "channel"
                renderChannelSelect(hostap.getBand.get)
              tdiv(class="card-table"):
                if hostap.isHidden:
                  label(class="card-title"): text "Unhide SSID"
                  input(`type`="checkbox", name="ssidCloak", value="0")
                else:
                  label(class="card-title"): text "Hide SSID"
                  input(`type`="checkbox", name="ssidCloak", value="1")
              tdiv(class="card-table"):
                label(class="card-title"): text "Password"
                input(`type`="password", name="password", placeholder="Please enter 8 to 64 characters") 
              button(`type`="submit", class="btn btn-apply saveBtn", name="saveBtn"):
                text "Save"
      table(class="full-width box-table"):
        tbody():
          tr():
            td(): text "SSID"
            td():
              strong():
                tdiv():
                  text hostap.getSSID.get
          tr():
            td(): text "Band"
            td():
              strong():
                tdiv():
                  text case hostap.getBand.get
                    of 'g':
                      "2.5GHz"
                    of 'a':
                      "5GHz"
                    else:
                      "Unknown"
          tr():
            td(): text "Channel"
            td():
              strong():
                tdiv():
                  text hostap.getChannel.get
          tr():
            td(): text "SSID Cloak"
            td():
              strong():
                tdiv():
                  text if hostap.isHidden: "Hidden" else: "Visible"
          tr():
            td(): text "Password"
            td():
              strong():
                if hostap.getPassword.get.len != 0:
                  tdiv(class="password_field_container"):
                    tdiv(class="black_circle")
                    icon "eye-off"
                    input(class="btn show_password", `type`="radio", name="password_visibility", value="show")
                    input(class="btn hide_password", `type`="radio", name="password_visibility", value="hide")
                    tdiv(class="shadow")
                    tdiv(class="password_preview_field"):
                      tdiv(class="shown_password"): text hostap.getPassword.get
                else:
                  tdiv():
                    text "No password has been set"

proc render*(status: HostApStatus): VNode =
  buildHtml(tdiv(class="columns width-38")):
    tdiv(class="box"):
      tdiv(class="box-header"):
        text "Actions"
      tdiv(class="card-padding"):
        form(`method`="post", action="/net/apctl", enctype="multipart/form-data"):
          if status.isActive:
            button(`type`="submit", class="btn btn-reload", name="ctl", value="reload"): text "Restart"
            button(`type`="submit", class="btn btn-disable", name="ctl", value="disable"): text "Disable"
          else:
            button(`type`="submit", class="btn btn-enable", name="ctl", value="enable"): text "Enable"

when isMainModule:
  when defined(dhclient):
    const cmd = "ps -ax | grep \"[d]hclient.wlan1\""
    let ps = execCmdEx(cmd)
    for v in ps.output.splitLines():
      let m = v.splitWhitespace(maxsplit = 4)
      let app = m[4]
      echo "app: ", app
      echo "line: ", m