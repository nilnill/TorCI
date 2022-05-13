import std / [ options ]
import karax / [ karaxdsl, vdom ]
import sys
# from ".." / ".." / settings import cfg, sysInfo
import ../ wirelessManager
from ../../ settings import cfg

method render*(self: SystemInfo): VNode {.base.} =
  const defStr = "None"
  buildHtml(tdiv(class="columns full-width")):
    tdiv(class="card card-padding card-sys"):
      tdiv(class="card-header"):
        text "System"
      table(class="table full-width"):
        tbody():
          tr():
            td(): text "Model"
            td():
              strong():
                tdiv():
                  text if self.model.len != 0: self.model else: defStr
          tr():
            td(): text "Kernel"
            td():
              strong():
                tdiv():
                  text if self.kernelVersion.len != 0: self.kernelVersion else: defStr
          tr():
            td(): text "Architecture"
            td():
              strong():
                tdiv():
                  text if self.architecture.len != 0: self.architecture else: defStr
          tr():
            td(): text "TorBox Version"
            td():
              strong():
                tdiv():
                  text if self.torboxVersion.len > 0: self.torboxVersion else: "Unknown"
          tr():
            td(): text "TorCI Version"
            td():
              strong():
                tdiv():
                  text cfg.torciVer

func render*(self: IoInfo, ap: ConnectedAp): VNode =
  const defStr = "None"
  buildHtml(tdiv(class="columns")):
    tdiv(class="card card-padding card-sky"):
      tdiv(class="card-header"):
        text "Network"
      table(class="table full-width"):
        tbody():
          tr():
            td(): text "Internet"
            td():
              strong():
                tdiv():
                  let internet = self.internet
                  text if internet.isSome: $get(internet)
                    else: defStr
          tr():
            td(): text "Host AP"
            td():
              strong():
                tdiv():
                  # let hostap = io.getHostap
                  # text if hostap.isSome: $hostap.get else: defStr
                  let hostap = self.hostap
                  text if hostap.isSome: $get(hostap)
                    else: defStr

          tr():
            td(): text "SSID"
            td():
              strong():
                tdiv():
                  text if ap.ssid.len != 0: ap.ssid else: defStr
          tr():
            td(): text "IP Address"
            td():
              strong():
                tdiv():
                  text if ap.ipAddr.len != 0: ap.ipaddr else: defStr
          tr():
            td(): text "VPN"
            td():
              strong():
                tdiv():
                  text if self.vpnIsActive: "is Up" else: defStr

func render*(self: Devices): VNode =
  buildHtml(tdiv(class="columns full-width")):
    tdiv(class="box"):
      tdiv(class="box-header"):
        text "Connected Devices"
      table(class="full-width box-table"):
        tbody():
          tr():
            th(): text "MAC Address"
            th(): text "IP Address"
            th(): text "Signal"
          for v in self:
            tr():
              td(): text if v.macaddr.len != 0: v.macaddr else: "None"
              td(): text if v.ipaddr.len != 0: v.ipaddr else: "None"