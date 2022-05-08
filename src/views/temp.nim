import karax / [ karaxdsl, vdom ]
import jester
import renderutils
import ".." / [ notice, settings ]
import ".." / routes / [ tabs ]
# import re, os

const
  doctype = "<!DOCTYPE html>\n"
  
proc renderHead(cfg: Config, title: string = ""): VNode =
  buildHtml(head):
    link(rel="stylesheet", `type`="text/css", href="/css/style.css")
    link(rel="stylesheet", type="text/css", href="/css/fontello.css?v=2")
    link(rel="apple-touch-icon", sizes="180x180", href="/apple-touch-icon.png")
    link(rel="icon", type="image/png", sizes="32x32", href="/favicon-32x32.png")
    link(rel="icon", type="image/png", sizes="16x16", href="/favicon-16x16.png")
    link(rel="manifest", href="/site.webmanifest")
    title: 
      if title.len > 0:
        text title & " | " & cfg.title
      else:
        text cfg.title
    meta(name="viewport", content="width=device-width, initial-scale=1.0")

proc renderNav(req: Request; username: string; tab: Tab = new Tab): VNode =
  result = buildHtml(header(class="headers")):
    nav(class="nav-container"):
      tdiv(class="inner-nav"):
        tdiv(class="linker-root"):
          a(class="", href="/"):
            img(class="logo-file", src="/images/torbox.png")
            tdiv(class="service-name"):text cfg.title
        tdiv(class="center-title"):
          text req.getCurrentTab()
        tdiv(class="tabs"):
          a(class=getNavClass(req.pathInfo, "/io"), href="/io"):
            icon "th-large", class="tab-icon"
            tdiv(class="tab-name"):
              text "Status"
          a(class=getNavClass(req.pathInfo, "/net"), href="/net"):
            icon "wifi", class="tab-icon"
            tdiv(class="tab-name"):
              text "Network"
          a(class=getNavClass(req.pathInfo, "/sys"), href="/sys"):
            icon "cog", class="tab-icon"
            tdiv(class="tab-name"):
              text "System"
        tdiv(class="user-drop"):
          icon "user-circle-o"
          input(class="popup-btn", `type`="radio", name="popup-btn", value="open")
          input(class="popout-btn", `type`="radio", name="popup-btn", value="close")
          tdiv(class="dropdown"):
            tdiv(class="panel"):
              tdiv(class="line"):
                icon "user-o"
                tdiv(class="username"): text "Username: " & username
              form(`method`="post", action="/io", enctype="multipart/form-data"):
                button(`type`="submit", name="tor-request", value="restart-tor"):
                  icon "cw"
                  tdiv(class="btn-text"): text "Restart Tor"
              form(`method`="post", action="/logout", enctype="multipart/form-data"):
                button(`type`="submit", name="signout", value="1"):
                  icon "logout"
                  tdiv(class="btn-text"): text "Log out"
        # tdiv(class="logout-button"):
        #   icon "logout"
    if not tab.isEmpty:
      tab.render(req.pathInfo)

proc renderError*(e: string): VNode =
  buildHtml():
    tdiv(class="content"):
      tdiv(class="panel-container"):
        tdiv(class="logo-container"):
          img(class="logo", src="/images/torbox.png", alt="TorBox")
        tdiv(class="error-panel"):
          span(): text e
          
proc renderClosed*(): VNode =
  buildHtml():
    tdiv(class="warn-panel"):
      icon "attention", class="warn-icon"
      tdiv(class="warn-subject"): text "Sorry..."
      tdiv(class="warn-description"):
        text "This feature is currently closed as it is under development and can cause bugs"

proc renderPanel*(v: VNode): VNode =
  buildHtml(tdiv(class="main-panel")):
    v

proc renderNode*(v: VNode; req: Request; username: string; title: string = "", tab: Tab = new Tab): string =
  let node = buildHtml(html(lang="en")):
    renderHead(cfg, title)

    body:
      if tab.isEmpty:
        renderNav(req, username)

      else:
        renderNav(req, username, tab)

      tdiv(class="container"):
        v
  result = doctype & $node

proc renderNode*(
  v: VNode;
  req: Request;
  username: string;
  title: string = "",
  tab: Tab = new Tab;
  notifies: Notifies): string =

  let node = buildHtml(html(lang="en")):
    renderHead(cfg, title)

    body:
      if tab.len != 0:
        renderNav(req, username, tab)

      else:
        renderNav(req, username)

      if not notifies.isEmpty:
        notifies.render()

      tdiv(class="container"):
        v

  result = doctype & $node

proc renderFlat*(v: VNode, title: string = ""): string =
  let ret = buildHtml(html(lang="en")):
    renderHead(cfg, title)
    body:
      v
  result = doctype & $ret

proc renderFlat*(v: VNode, title: string = "", notifies: Notifies): string =
  let ret = buildHtml(html(lang="en")):
    renderHead(cfg, title)
    body:
      notifies.render
      v
  result = doctype & $ret