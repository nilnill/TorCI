import os, osproc, re, asyncdispatch, strutils
import ".."/[types]

proc getBridgesStatus*(): Future[tuple[useBridges, obfs4, meekAzure, snowflake: bool]] {.async.} =
  try:
    let rc = readFile(torrc)
    for line in rc.splitLines():
      if line.startsWith("Use Bridges 1"):
        result.useBridges = true
        continue
      elif line.startsWith("Bridge obfs4 "):
        result.obfs4 = true
        continue
      elif line.startsWith("Bridge meek_lite "):
        result.meekAzure = true
        continue
      elif line.startsWith("Bridge snowflake "):
        result.snowflake = true
        continue
  except: return

proc getObfs4Count(): tuple[activated, deactivated, total: int] =
  let rc = readFile(torrc)
  for v in rc.splitLines():
    if v.startsWith("Bridge obfs4 "):
      result.activated += 1
      result.total += 1
    elif v.startsWith("#Bridge obfs4 "):
      result.deactivated += 1
      result.total += 1
      
# This function deactivates the bridge relay.
proc deactivateBridgeRelay() =
  var
    rc = readFile(torrc)
    activeRelay: bool
    orport, obfs4port: string

  for v in rc.splitLines():
    if v.startsWith("BridgeRelay 1"):
      activeRelay = true

  if activeRelay:
    for v in rc.splitLines():
      if v.startsWith("ORPort"):
        orport = v.splitWhitespace()[1]

      elif v.startsWith("ServerTransportListenAddr"):
        obfs4port = v.split(":")[1]
    
    rc = rc.replacef(re"BridgeRelay\s(\d+)", "#BridgeRelay $1")
    rc = rc.replacef(re"ORPort\s(\d+)", "#ORPort $1")
    rc = rc.replacef(re"ExtORPort\s(\w+)", "#ExtORPort $1")
    rc = rc.replacef(re"ServerTransportPlugin\s(.*)", "#ServerTransportPlugin $1")
    rc = rc.replacef(re"ServerTransportListenAddr\s(.*)", "#ServerTransportListenAddr $1")
    rc = rc.replacef(re"ContactInfo\s(.*)", "#ContactInfo $1")
    rc = rc.replacef(re"Nickname\s(.*)", "#Nickname $1")
    rc = rc.replacef(re"BridgeDistribution\s(.*)", "#BridgeDistribution $1")

    torrc.writeFile rc
    
    discard execCmd("sudo iptables -D INPUT -p tcp --dport $sORPORT -j ACCEPT")
    discard execCmd("sudo iptables -D INPUT -p tcp --dport $sOBFS4PORT -j ACCEPT")
    
proc activateAllConfiguredObfs4*() {.async.} =
  let (activated, _, _) = getObfs4Count()
  if activated > 0:
    deactivateBridgeRelay()
    var rc = readFile(torrc)
    rc = rc.replacef(re"#UseBridges\s(\d+)", "UseBridges $1")
    rc = rc.replacef(re"#UpdateBridgesFromAuthority\s(\d+)", "UpdateBridgesFromAuthority $1")
    rc = rc.replacef(re"#ClientTransportPlugin meek_lite,obfs4\s(.*)", "ClientTransportPlugin meek_lite,obfs4 $1")
    rc = rc.replacef(re"ClientTransportPlugin snowflake\s(.*)", "#ClientTransportPlugin snowflake $1")
    rc = rc.replacef(re"Bridge snowflake\s(.*)", "#Bridge snowflake $1")
    rc = rc.replacef(re"Bridge meek_lite\s(.*)", "#Bridge meek_lite $1")

    torrc.writeFile(rc)
    
# proc activateOnlineObfs4*() {.async.} =