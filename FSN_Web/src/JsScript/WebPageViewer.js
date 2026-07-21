function InitializeIFrame(n) {
    SetIFrameSize(n)
}
function InitializeFullIFrame() {
    SetFullIFrameSize()
}
function SetIFrameSize(n) {
    var i = document.getElementById("controlAddIn"),
    f = i.offsetWidth,
    e = i.offsetHeight,
    r = n.split(":"),
    o = r[0],
    u = r[1],
    t = Math.ceil((e - pageTabSize) / u);
    do
        iframeWidth = Math.ceil(t * o), t--;
    while (iframeWidth > f);
    iframeHeight = (t + 1) * u + pageTabSize,
    iframeWidth = iframeWidth < maxSize ? defaultSize : iframeWidth,
    iframeHeight = iframeHeight < maxSize ? defaultSize : iframeHeight
}
function SetFullIFrameSize() {
    var n = document.getElementById("controlAddIn"),
    t = n.offsetWidth,
    i = n.offsetHeight
}
function SetContent(n, t) {
    iframe = WebPageViewerHelper.CreateIFrame(iframeHeight, iframeWidth),
    WebPageViewerHelper.SetBodyContent(iframe),
    WebPageViewerHelper.IFrameReady(iframe, function (i) {
        iframe.contentDocument.body.innerHTML = n,
        typeof t != "undefined" && WebPageViewerHelper.RunJavascript(t, iframe.contentDocument),
        WebPageViewerHelper.UpdateLinks(),
        WebPageViewerHelper.ChildDocumentReady(),
        WebPageViewerHelper.HideSpinner(),
        i.preventLoadEvent()
    })
}
function Navigate(n, t, i) {
    iframe = WebPageViewerHelper.CreateIFrame(iframeHeight, iframeWidth);
    try {
        if (typeof t == "undefined" || typeof i == "undefined") {
            if (n.substring(0, 7).toLowerCase() !== "http://")
                throw "Insecure URL Specified";
            WebPageViewerHelper.SetBodyContent(iframe),
            subscribeToSrcLoad = WebPageViewerHelper.BindSrcLoadEvent(iframe),
            WebPageViewerHelper.IFrameReady(iframe, function () {
                iframe.setAttribute("src", n),
                WebPageViewerHelper.ChildDocumentReady()
            });
            return
        }
        i = JSON.parse(i);
        var r = WebPageViewerHelper.CreateFormWithData(t, n, i);
        WebPageViewerHelper.SetBodyContent(iframe),
        WebPageViewerHelper.IFrameReady(iframe, function () {
            iframe.contentDocument.body.appendChild(r),
            r.submit(),
            WebPageViewerHelper.ChildDocumentReady()
        })
    } catch (u) {
        WebPageViewerHelper.HandleException(u),
        WebPageViewerHelper.HideSpinner()
    }
}
function LinksOpenInNewWindow() {
    WebPageViewerHelper.Properties.LinksOpenInNewWindow = !0,
    WebPageViewerHelper.UpdateLinks()
}
function InvokeEvent(n) {
    WebPageViewerHelper.TriggerEvent(n)
}
function SetCallbacksFromSubscribedEventToIgnore(n, t) {
    if (typeof n != "string" || !n)
        return;
    t || (t = []),
    WebPageViewerHelper.SetCallbacksFromSubscribedEventToIgnore(n, t)
}
function SubscribeToEvent(n, t) {
    var i = "*",
    r;
    if (t !== "undefined") {
        if (t.substring(0, 7).toLowerCase() !== "http://")
            throw "Insecure URL Specified";
        i = t.substring(0, t.indexOf("/", 8))
    }
    r = function (t) {
        var f,
        r,
        u;
        if (t.origin !== i)
            return;
        f = JSON.stringify(t.data),
        r = WebPageViewerHelper.Properties.IgnoreCallbacks[n];
        if (r)
            for (u = 0; u < r.length; u++)
                if (r[u] === f)
                    return;
        WebPageViewerHelper.TriggerCallback(f)
    },
    WebPageViewerHelper.SubscribeToEvent(n, r)
}
function PostMessage(n, t, i) {
    if (typeof n != "string" || !n)
        return;
    if (typeof t != "string" || !t)
        return;
    i && (n = JSON.parse(n)),
    subscribeToSrcLoad && subscribeToSrcLoad(function () {
        iframe.contentWindow.postMessage(n, t)
    })
}

function ResponseToSrcLoad(n) {
    WebPageViewerHelper.res
}

window.addEventListener("message", function(event) {
    console.log("Mensaje recibido:", event);
    // Puedes validar el origen aquí si lo necesitas
    if (event.data && event.data.eventName === "ProductosRecibidos") {
        // Procesa los productos recibidos
        var productos = event.data.data;
        // Llama a tu función de helper para enviar a NAV
        console.log("Productos recibidos:", productos);
        if (typeof WebPageViewerHelper.TriggerProductosRecibidos === "function") {
            WebPageViewerHelper.TriggerProductosRecibidos(productos);
        }
    }
}, false)
window.addEventListener("message", function(event) {
    console.log("Mensaje recibido:", event);
    // Puedes validar el origen aquí si lo necesitas
    if (event.data && event.data.eventName === "HistoricoVenta") {
        // Procesa los productos recibidos
        var productos = event.data.data;
        // Llama a tu función de helper para enviar a NAV
        console.log("Productos recibidos:", productos);
        if (typeof WebPageViewerHelper.TriggerHistoricoVenta === "function") {
            WebPageViewerHelper.TriggerHistoricoVenta(productos);
        }
    }
}, false)
window.addEventListener("message", function(event) {
    // Puedes validar el origen aquí si lo necesitas
    if (event.data && event.data.eventName === "CrearCliente") {
        // Procesa los productos recibidos
        var cliente = event.data.data;
        // Llama a tu función de helper para enviar a NAV
        console.log("Datos de nuevo cliente recibidos:", cliente);
        if (typeof WebPageViewerHelper.TriggerCrearCliente === "function") {
            WebPageViewerHelper.TriggerCrearCliente(cliente);
        }
    }
}, false)
window.addEventListener("message", function(event) {
    // Puedes validar el origen aquí si lo necesitas
    if (event.data && event.data.eventName === "RecibirDatos") {
        // Procesa los productos recibidos
        var cliente = event.data.data;
        // Llama a tu función de helper para enviar a NAV
        console.log("Datos de cliente recibidos:", cliente);
        if (typeof WebPageViewerHelper.TriggerRecibirDatos === "function") {
            WebPageViewerHelper.TriggerRecibirDatos(cliente);
        }
    }
}, false)
var iframe = null
  , subscribeToSrcLoad = function() {}
  , maxSize = 300
  , defaultSize = "100%"
  , iframeHeight = defaultSize
  , iframeWidth = defaultSize
  , pageTabSize = 20;
  Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('ControlAddInReady', [WebPageViewerHelper.GetCallbackURL()]);

