var WebPageViewerHelper = {
    Initialize: function () {
        var n;
        if (WebPageViewerHelper.IsRunningOnIos())
            return;
        n = document.createElement("div"),
        n.setAttribute("id", "spinner")
    },
    DisplaySpinner: function () {
        var n = document.getElementById("spinner"),
        t;
        n != null && n.setAttribute("style", "display: block"),
        t = document.getElementById("controlAddIn"),
        t.display = "none"
    },
    HideSpinner: function () {
        var n = document.getElementById("spinner"),
        t;
        n != null && n.setAttribute("style", "display: none"),
        t = document.getElementById("controlAddIn"),
        t.display = "block"
    },
    CreateIFrame: function (n, t) {
        WebPageViewerHelper.DisplaySpinner();
        var i = document.createElement("iframe");
        return i.setAttribute("height", n),
        i.setAttribute("width", t),
        i.setAttribute("frameBorder", "0"),
        i.setAttribute("seamless", "seamless"),
        i
    },
    IFrameReady: function (n, t) {
        var i = function () {
            WebPageViewerHelper.HideSpinner(),
            n.removeEventListener("load", i)
        },
        r = setInterval(function () {
            try {
                if (n.contentDocument && n.contentDocument.body) {
                    n.addEventListener("load", i),
                    n.contentDocument.body.setAttribute("style", "margin: 0px; padding: 0px;");
                    var u = {
                        preventLoadEvent: function () {
                            n.removeEventListener("load", i)
                        }
                    };
                    t(u),
                    clearInterval(r)
                }
            } catch (f) {
                clearInterval(r)
            }
        }, 5)
    },
    CreateInput: function (n, t) {
        var i = document.createElement("input");
        return i.setAttribute("type", "hidden"),
        i.setAttribute("name", n),
        i.setAttribute("value", t),
        i
    },
    CreateFormWithData: function (n, t, i) {
        var r,
        u,
        f;
        if (!(n.toUpperCase() === "GET" || n.toUpperCase() === "POST"))
            throw "Unsupported Method Specified";
        if (t.substring(0, 7).toLowerCase() !== "http://")
            throw "Insecure URL Specified";
        r = document.createElement("form"),
        r.setAttribute("method", n),
        r.setAttribute("action", t);
        for (u in i)
            f = WebPageViewerHelper.CreateInput(decodeURIComponent(u), decodeURIComponent(i[u])), r.appendChild(f);
        return r
    },
    RunJavascript: function (n, t) {
        var i = document.createElement("script");
        i.type = "text/javascript",
        i.text = n,
        t.head.appendChild(i)
    },
    SetBodyContent: function (n) {
        var t = window.document.getElementById("controlAddIn");
        t.innerHTML = "",
        t.appendChild(n),
        WebPageViewerHelper.IsRunningOnIos() && t.classList.add("ms-dyn-nav-scrollable"),
        WebPageViewerHelper.Properties.BodyContent = n
    },
    GetCallbackURL: function () {
        var i = document.location.protocol,
        t = document.location.host
        n = "";
        return t == "" ? n : n.indexOf(i + "//") == 0 ? n : i + "//" + t + n
    },
    TriggerCallback: function (n) {
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod("Callback", [n])
    },

    TriggerProductosRecibidos: function (n) {
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod("ProductosRecibidos", [n])
    },
    
    TriggerHistoricoVenta: function (n) {
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod("HistoricoVenta", [n])
    },
     TriggerCrearCliente: function (n) {
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod("CrearCliente", [n])
    },
     TriggerRecibirDatos: function (n) {
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod("RecibirDatos", [n])
    },
    ChildDocumentReady: function () {
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod("DocumentReady")
    },
    TriggerEvent: function (n) {
        var i = WebPageViewerHelper.Properties.BodyContent,
        t;
        if (!(i && i.contentWindow))
            return;
        i.contentDocument.createEvent ? (t = i.contentDocument.createEvent("CustomEvent"), t.initEvent("webpageviewerevent", !0, !0), t.data = n) : t = new CustomEvent("webpageviewerevent", n),
        window.dispatchEvent(t)
    },
    LinksOpenInNewWindow: function () {
        var i = WebPageViewerHelper.Properties.BodyContent,
        t,
        n;
        if (!i || !i.contentDocument)
            return;
        for (i = i.contentDocument, t = i.getElementsByTagName("a"), n = 0; n < t.length; n++)
            t[n].hasAttribute("href") && function () {
                var i = t[n].getAttribute("href");
                t[n].setAttribute("href", "#"),
                t[n].addEventListener("click", function (n) {
                    Microsoft.Dynamics.NAV.OpenWindow(i),
                    n.preventDefault()
                })
            }
        ()
    },
    UpdateLinks: function () {
        WebPageViewerHelper.Properties.LinksOpenInNewWindow && WebPageViewerHelper.LinksOpenInNewWindow()
    },
    SetCallbacksFromSubscribedEventToIgnore: function (n, t) {
        WebPageViewerHelper.Properties.IgnoreCallbacks[n] = t
    },
    SubscribeToEvent: function (n, t) {
        WebPageViewerHelper.Properties.SubscribedEvents.indexOf(n) < 0 && (WebPageViewerHelper.Properties.SubscribedEvents.push(n), window.addEventListener(n, t))
    },
    HandleException: function (n) {
        var u = n + ".",
        f = "Please contact your system administrator.",
        t = document.createElement("div"),
        i = document.createElement("h1"),
        r = document.createElement("h2");
        t.textContent === "" ? (i.textContent = u, r.textContent = f) : (i.innerText = u, r.innerText = f),
        t.appendChild(i),
        t.appendChild(r),
        WebPageViewerHelper.SetBodyContent(t)
    },
    IsRunningOnIos: function () {
        return WebPageViewerHelper.FindInUserAgentString("IPAD") || WebPageViewerHelper.FindInUserAgentString("IPOD") || WebPageViewerHelper.FindInUserAgentString("IPHONE")
    },
    FindInUserAgentString: function (n) {
        return WebPageViewerHelper.GetUserAgentString().indexOf(n) > -1
    },
    GetUserAgentString: function () {
        return WebPageViewerHelper.Properties.UserAgentString == null && (WebPageViewerHelper.Properties.UserAgentString = window.navigator.userAgent.toUpperCase()),
        WebPageViewerHelper.Properties.UserAgentString
    },
    BindSrcLoadEvent: function (n) {
        var i = !1,
        t = [],
        r = function () {
            if (n.src) {
                n.removeEventListener("load", r),
                i = !0;
                for (var u = 0; u < t.length; u++)
                    t[u]()
            }
        };
        return n.addEventListener("load", r),
        function (n) {
            typeof n == "function" && t.indexOf(n) < 0 && (t.push(n), i && n())
        }
    },
    Properties: {
        BodyContent: null,
        LinksOpenInNewWindow: !1,
        UserAgentString: null,
        SubscribedEvents: [],
        IgnoreCallbacks: {}
    }
};



