import karax/[karaxdsl, vdom]
import ".." / ".." / [types]

proc renderObfs4Ctl*(): VNode =
  buildHtml(tdiv(class="columns width-50")):
    tdiv(class="box"):
      tdiv(class="box-header"):
        text "Bridges Control"
      form(`method`="post", action="/net/bridges", enctype="multipart/form-data"):
        table(class="full-width box-table"):
          tbody():
            tr():
              td(): text "All configured Obfs4"
              td():
                strong():
                  button(`type`="submit", name="obfs4", value="all"):
                    text "Activate"
            tr():
              td(): text "Online Obfs4 only"
              td():
                strong():
                  button(`type`="submit", name="obfs4", value="online"):
                    text "Activate"
            tr():
              td(): text "Auto Obfs4 "
              td():
                strong():
                  button(`type`="submit", name="auto-add-obfs4", value="1"):
                    text "Add"

proc renderBridgeActions*(bridgesSta: BridgeStatuses): VNode =
  buildHtml(tdiv(class="columns width-50")):
    tdiv(class="box"):
      tdiv(class="box-header"):
        text "Bridges Control"
      form(`method`="post", action="/net/bridges", enctype="multipart/form-data"):
        table(class="full-width box-table"):
          tbody():
            tr():
              td(): text "Obfs4"
              td():
                strong():
                  if bridgesSta.obfs4:
                    button(class="btn-general btn-danger", `type`="submit", name="bridge-action", value="obfs4-deactivate"):
                      text "Deactivate"
                  else:
                    button(class="btn-general btn-safe", `type`="submit", name="bridge-action", value="obfs4-activate-all"):
                      text "Activate"

            tr():
              td(): text "Meek-Azure"
              td():
                strong():
                  if bridgesSta.meekAzure:
                    button(class="btn-general btn-danger", `type`="submit", name="bridge-action", value="meekazure-deactivate"):
                      text "Deactivate"
                  else:
                    button(class="btn-general btn-safe", `type`="submit", name="bridge-action", value="meekazure-activate"):
                      text "Activate"

            tr():
              td(): text "Snowflake"
              td():
                strong():
                  if bridgesSta.snowflake:
                    button(class="btn-general btn-danger", `type`="submit", name="bridge-action", value="snowflake-deactivate"):
                      text "Deactivate"
                  else:
                    button(class="btn-general btn-safe", `type`="submit", name="bridge-action", value="snowflake-activate"):
                      text "Activate"
                    
proc renderInputObfs4*(): VNode =
  buildHtml(tdiv(class="columns width-50")):
    tdiv(class="box"):
      tdiv(class="box-header"):
        text "Add Obfs4 Bridges"
      form(`method`="post", action="/net/bridges", enctype="multipart/form-data"):
        textarea(
          class="textarea bridge-input",
          name="input-bridges",
          placeholder="e.g.\n" &
          "obfs4 xxx.xxx.xxx.xxx:xxxx FINGERPRINT cert=abcd.. iat-mode=0\n" &
          "meek_lite 192.0.2.2:2 97700DFE9F483596DDA6264C4D7DF7641E1E39CE url=https://meek.azureedge.net/ front=ajax.aspnetcdn.com\n" &
          "snowflake 192.0.2.3:1 2B280B23E1107BB62ABFC40DDCC8824814F80A72",
          required=""
        )
        button(class="btn-apply", `type`="submit", name="bridges-ctl", value="1"): text "Add Bridges"